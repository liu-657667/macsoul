#!/usr/bin/env python3
"""Isolated automatic-verification regressions; fixtures are NOT Owner evidence."""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import verify_v011 as verify


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='macsoul-v011-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'repo'; self.root.mkdir()
        for folder in ('scripts', 'MacSoul', 'MacSoulTests', 'MacSoul.xcodeproj', 'docs'):
            (self.root / folder).mkdir()
        (self.root / '.gitignore').write_text('.artifacts/\n__pycache__/\n*.pyc\n')
        (self.root / 'README.md').write_text('# Fixture\n')
        (self.root / 'MacSoul/input.swift').write_text('// simulation fixture\n')
        self.git('init', '-q', '-b', 'fixture-feature')
        self.git('config', 'user.name', 'Isolated verification fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('add', '.gitignore', 'README.md', 'MacSoul/input.swift')
        self.git('commit', '-qm', 'isolated fixture, never pushed')
        # Current v0.1.1 harness only: a local read-only remote for exact-ref
        # queries. Checkout-normalization regressions use a separate bare origin.
        self.git('remote', 'add', 'origin', str(self.root))
        self.initial = verify.identity(self.root)
        self.run_id = 'TEST_FIXTURE_ONLY'
        self.run = self.root / '.artifacts/v0.1.1-runs' / self.run_id
        self.run.mkdir(parents=True)
        self.commands = {name: [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")'] for name in verify.REQUIRED}

    def git(self, *args):
        return verify.git(self.root, *args)

    def receipt(self):
        result = {'schema': verify.SCHEMA, 'run_id': self.run_id, 'identity': self.initial,
                  'unexecuted': dict(verify.UNEXECUTED), 'status': 'PASS', 'checks': {},
                  'started_at': verify.now(), 'ci': 'NOT_RUN', 'toolchain': {'xcode': 'TEST_FIXTURE_ONLY', 'macos': 'TEST_FIXTURE_ONLY'},
                  'historical_scope': {'revision': verify.HISTORICAL, 'tree': verify.HISTORICAL_TREE,
                                       'fingerprint': verify.HISTORICAL_FP, 'owner_decision_sha256': verify.HISTORICAL_DECISION}}
        for name, argv, code in (
            ('history_preparation', [sys.executable, 'scripts/verify_v011.py', 'prepare-history', '--frozen', str(self.run / 'historical')], 0),
            ('current_fixed_validator_diagnostic', [sys.executable, 'scripts/verify_doc_maintenance.py', 'check'], 1)):
            log = self.run / (name + '.log'); log.write_text('TEST_FIXTURE_ONLY\n')
            result[name] = dict(argv=argv, exit_code=code, status='PASS' if code == 0 else 'FAIL',
                                started_at=verify.now(), ended_at=verify.now(), log=str(log.relative_to(self.root)),
                                log_sha256=verify.sha(log.read_bytes()))
        for name in verify.REQUIRED:
            log = self.run / (name + '.log'); log.write_text('TEST_FIXTURE_ONLY\n')
            item = dict(argv=self.commands[name], status='PASS', exit_code=0,
                        log=str(log.relative_to(self.root)), log_sha256=verify.sha(log.read_bytes()),
                        started_at=verify.now(), ended_at=verify.now())
            if name in ('unit', 'network'):
                summary = self.run / (name + '-summary.json')
                summary.write_text(json.dumps(dict(totalTestCount=1, failedTests=0, skippedTests=0, result='Passed')))
                item['counts'] = dict(tests=1, failures=0, skips=0, result='Passed',
                                      summary=str(summary.relative_to(self.root)), summary_sha256=verify.sha(summary.read_bytes()))
            result['checks'][name] = item
        if self.initial['checkout_kind'] == 'CI_CLEAN' and hasattr(self, 'tag_env'):
            comparison = verify.ci_whitespace_range(self.root, self.tag_env)
            result['tag_identity'] = comparison['tag_identity']
            result['tag_event'] = comparison['tag_event']
        return result

    def validate(self, receipt):
        verify.validate_receipt(self.root, receipt, self.initial, self.run_id, self.commands)

    def test_exact_fixture_receipt_consistency(self):
        self.validate(self.receipt())

    def test_missing_stage_rejected(self):
        data = self.receipt(); del data['checks']['unit']
        with self.assertRaisesRegex(ValueError, 'missing/extra'):
            self.validate(data)

    def test_each_failed_stage_rejected(self):
        for name in verify.REQUIRED:
            with self.subTest(name=name):
                data = self.receipt(); data['checks'][name].update(exit_code=65, status='FAIL')
                with self.assertRaisesRegex(ValueError, 'required check failed'):
                    self.validate(data)

    def test_exit_status_mismatch_rejected(self):
        data = self.receipt(); data['checks']['unit']['exit_code'] = 65
        with self.assertRaisesRegex(ValueError, 'command/result mismatch'):
            self.validate(data)

    def test_wrong_command_rejected(self):
        data = self.receipt(); data['checks']['unit']['argv'] = ['true']
        with self.assertRaisesRegex(ValueError, 'command/result mismatch'):
            self.validate(data)

    def test_old_receipt_version_and_run_rejected(self):
        for field, value in (('schema', 'v0.1.0'), ('run_id', 'old-run')):
            with self.subTest(field=field):
                data = self.receipt(); data[field] = value
                with self.assertRaisesRegex(ValueError, 'wrong/stale'):
                    self.validate(data)

    def test_missing_history_preparation_diagnostic_toolchain_and_scope_rejected(self):
        for name in ('history_preparation', 'current_fixed_validator_diagnostic', 'toolchain', 'historical_scope'):
            data = self.receipt(); del data[name]
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.validate(data)

    def test_stale_command_timestamp_and_fake_remote_ci_rejected(self):
        data = self.receipt(); data['checks']['unit']['started_at'] = '2000-01-01T00:00:00+00:00'
        with self.assertRaisesRegex(ValueError, 'timestamp'):
            self.validate(data)
        data = self.receipt(); data['ci'] = 'SUCCESS'
        with self.assertRaisesRegex(ValueError, 'local receipt cannot claim'):
            self.validate(data)

    def test_dirty_ci_preflight_keeps_failure_receipt_instead_of_old_pass(self):
        (self.root / 'README.md').write_text('dirty CI fixture')
        with patch.dict('os.environ', {'GITHUB_ACTIONS': 'true'}):
            self.assertEqual(verify.run_all(self.root), 1)
        data = json.loads((self.root / '.artifacts/v0.1.1-verification.json').read_text())
        self.assertEqual(data['status'], 'FAIL'); self.assertEqual(data['checks'], {})
        self.assertIn('must remain clean', data['error'])

    def test_each_wrong_candidate_identity_rejected(self):
        for field in ('git_revision', 'git_tree', 'source_fingerprint', 'patch_sha256', 'inputs_sha256', 'index_sha256'):
            with self.subTest(field=field):
                data = self.receipt(); data['identity'] = copy.deepcopy(self.initial)
                data['identity'][field] = '0' * 64
                with self.assertRaisesRegex(ValueError, 'wrong/stale'):
                    self.validate(data)

    def test_no_automatic_owner_or_live_pass(self):
        for name in verify.UNEXECUTED:
            data = self.receipt(); data['unexecuted'][name] = 'PASS'
            with self.assertRaisesRegex(ValueError, 'cannot grant'):
                self.validate(data)

    def test_missing_changed_and_stale_log_rejected(self):
        for scenario in ('missing', 'changed', 'stale'):
            with self.subTest(scenario=scenario):
                data = self.receipt(); item = data['checks']['build']; path = self.root / item['log']
                if scenario == 'missing':
                    path.unlink()
                elif scenario == 'changed':
                    path.write_text('different output')
                else:
                    stale = self.root / '.artifacts/old-build.log'; stale.write_bytes(path.read_bytes())
                    item['log'] = str(stale.relative_to(self.root))
                with self.assertRaises(ValueError):
                    self.validate(data)

    def test_missing_summary_and_false_counts_rejected(self):
        for scenario in ('missing', 'changed', 'false-counts', 'zero-tests', 'test-failure'):
            with self.subTest(scenario=scenario):
                data = self.receipt(); counts = data['checks']['unit']['counts']; summary = self.root / counts['summary']
                if scenario == 'missing':
                    summary.unlink()
                elif scenario == 'changed':
                    summary.write_text('{}')
                elif scenario == 'false-counts':
                    counts['tests'] = 999
                else:
                    raw = dict(totalTestCount=0 if scenario == 'zero-tests' else 1,
                               failedTests=1 if scenario == 'test-failure' else 0, skippedTests=0,
                               result='Failed' if scenario == 'test-failure' else 'Passed')
                    summary.write_text(json.dumps(raw)); counts.update(tests=raw['totalTestCount'], failures=raw['failedTests'],
                                                                      result=raw['result'], summary_sha256=verify.sha(summary.read_bytes()))
                with self.assertRaises((ValueError, OSError)):
                    self.validate(data)

    def test_392_tests_zero_failures_five_skips_rejected(self):
        for name in ('network', 'unit'):
            with self.subTest(name=name):
                data = self.receipt(); counts = data['checks'][name]['counts']; summary = self.root / counts['summary']
                summary.write_text(json.dumps(dict(totalTestCount=392, failedTests=0, skippedTests=5, result='Passed')))
                counts.update(tests=392, failures=0, skips=5, result='Passed', summary_sha256=verify.sha(summary.read_bytes()))
                with self.assertRaisesRegex(ValueError, 'required tests did not pass'):
                    self.validate(data)

    def test_skips_cannot_be_hidden_by_changing_receipt_counts(self):
        data = self.receipt(); counts = data['checks']['unit']['counts']; summary = self.root / counts['summary']
        summary.write_text(json.dumps(dict(totalTestCount=392, failedTests=0, skippedTests=5, result='Passed')))
        counts.update(tests=392, skips=0, summary_sha256=verify.sha(summary.read_bytes()))
        with self.assertRaisesRegex(ValueError, 'summary/count mismatch'):
            self.validate(data)
        # Rewriting the original summary without updating its recorded digest is
        # rejected too; tests never sanitize a real xcresult's skipped count.
        summary.write_text(json.dumps(dict(totalTestCount=392, failedTests=0, skippedTests=0, result='Passed')))
        with self.assertRaisesRegex(ValueError, 'changed test summary'):
            self.validate(data)

    def ci_environment(self, event, payload, root=None):
        root = self.root if root is None else root
        p = root / '.artifacts/TEST_FIXTURE_ONLY-event.json'; p.parent.mkdir(exist_ok=True)
        p.write_text(json.dumps(payload))
        return dict(GITHUB_ACTIONS='true', GITHUB_EVENT_NAME=event, GITHUB_EVENT_PATH=str(p),
                    GITHUB_SHA=verify.git(root, 'rev-parse', 'HEAD').decode().strip())

    def successor(self, text):
        (self.root / 'README.md').write_text(text)
        self.git('add', 'README.md'); self.git('commit', '-qm', 'isolated whitespace fixture, never pushed')
        return self.git('rev-parse', 'HEAD').decode().strip()

    def test_local_tracked_staged_and_untracked_whitespace_fail(self):
        p = self.root / 'README.md'; p.write_text('TEST_FIXTURE_ONLY bad \n')
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, {})
        self.git('add', 'README.md'); p.write_text('# Clean final worktree\n')
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, {})
        self.git('add', 'README.md')
        (self.root / 'new.md').write_text('TEST_FIXTURE_ONLY bad \n')
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, {})

    def test_local_normal_tracked_staged_untracked_files_pass(self):
        (self.root / 'README.md').write_text('# Clean staged\n'); self.git('add', 'README.md')
        (self.root / 'README.md').write_text('# Clean unstaged\n')
        (self.root / 'new.md').write_text('# Clean untracked\n')
        result = verify.whitespace_check(self.root, {})
        self.assertEqual(result['untracked_paths'], ['new.md'])

    def test_ci_push_committed_whitespace_fails_and_normal_passes(self):
        for text, bad in (('TEST_FIXTURE_ONLY bad \n', True), ('# Clean successor\n', False)):
            before = self.git('rev-parse', 'HEAD').decode().strip(); after = self.successor(text)
            env = self.ci_environment('push', dict(before=before, after=after))
            if bad:
                with self.assertRaises(subprocess.CalledProcessError):
                    verify.whitespace_check(self.root, env)
            else:
                self.assertEqual(verify.whitespace_check(self.root, env)['baseline'], before)

    def test_ci_shallow_push_requires_exact_baseline_then_detects_whitespace(self):
        before = self.initial['git_revision']; after = self.successor('TEST_FIXTURE_ONLY bad \n')
        clone = Path(self.temp.name) / 'shallow-whitespace'
        subprocess.run(['git', 'clone', '--depth', '1', '--no-local', str(self.root), str(clone)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        subprocess.run(['git', '-C', str(clone), 'checkout', '--detach'], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        env = self.ci_environment('push', dict(before=before, after=after), clone)
        with self.assertRaisesRegex(ValueError, 'push before object'):
            verify.whitespace_check(clone, env)
        subprocess.run(['git', '-C', str(clone), 'fetch', '--depth', '1', '--no-tags', str(self.root), before],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(clone, env)

    def pr_fixture(self, text):
        self.git('checkout', '-qb', 'fixture-base')
        (self.root / 'base-only.md').write_text('TEST_FIXTURE_ONLY base whitespace \n')
        self.git('add', 'base-only.md'); self.git('commit', '-qm', 'isolated unrelated base update')
        base = self.git('rev-parse', 'HEAD').decode().strip()
        self.git('checkout', '-qb', 'fixture-head', self.initial['git_revision']); tip = self.successor(text)
        self.git('checkout', '-q', 'fixture-base')
        self.git('merge', '--no-ff', '-qm', 'isolated synthetic merge fixture', 'fixture-head')
        merge = self.git('rev-parse', 'HEAD').decode().strip()
        return base, tip, merge

    def test_ci_pr_synthetic_merge_rejects_head_whitespace(self):
        base, tip, merge = self.pr_fixture('TEST_FIXTURE_ONLY head whitespace \n')
        event = dict(pull_request=dict(base=dict(sha=base), head=dict(sha=tip)))
        env = self.ci_environment('pull_request', event)
        comparison = verify.ci_whitespace_range(self.root, env)
        self.assertEqual((comparison['baseline'], comparison['target']), (base, merge))
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, env)
        self.git('checkout', '--detach', tip)
        env = self.ci_environment('pull_request', event)
        self.assertEqual(verify.ci_whitespace_range(self.root, env)['baseline'], self.initial['git_revision'])
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, env)

    def test_ci_pr_normal_merge_and_shallow_prepared_objects_pass(self):
        base, tip, merge = self.pr_fixture('# Clean PR change\n')
        event = dict(pull_request=dict(base=dict(sha=base), head=dict(sha=tip)))
        # Unrelated existing base whitespace is not this PR's added content.
        self.assertEqual(verify.whitespace_check(self.root, self.ci_environment('pull_request', event))['baseline'], base)
        clone = Path(self.temp.name) / 'shallow-pr'
        subprocess.run(['git', 'clone', '--depth', '1', '--no-local', str(self.root), str(clone)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        env = self.ci_environment('pull_request', event, clone)
        with self.assertRaisesRegex(ValueError, 'PR base object'):
            verify.whitespace_check(clone, env)
        for revision in (base, tip):
            subprocess.run(['git', '-C', str(clone), 'fetch', '--depth', '1', '--no-tags', str(self.root), revision],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.assertEqual(verify.whitespace_check(clone, env)['target'], merge)

    def test_ci_missing_mismatched_and_unsupported_baselines_refused(self):
        head = self.initial['git_revision']
        for event, payload, message in (
            ('push', dict(before='0' * 39 + '1', after=head), 'push before object'),
            ('push', dict(before=head, after='0' * 39 + '1'), 'push after object'),
            ('push', dict(before='0' * 40, after=head), 'missing default branch'),
            ('workflow_dispatch', {}, 'unsupported/missing CI event')):
            env = self.ci_environment(event, payload)
            with self.subTest(event=event, payload=payload), self.assertRaisesRegex(ValueError, message):
                verify.whitespace_check(self.root, env)
        env = dict(GITHUB_ACTIONS='true', GITHUB_SHA=head, GITHUB_EVENT_NAME='push')
        with self.assertRaisesRegex(ValueError, 'missing CI event payload'):
            verify.whitespace_check(self.root, env)
        base, tip, merge = self.pr_fixture('# Clean PR change\n')
        env = self.ci_environment('pull_request', dict(pull_request=dict(base=dict(sha=self.initial['git_revision']), head=dict(sha=tip))))
        with self.assertRaisesRegex(ValueError, 'merge parents'):
            verify.whitespace_check(self.root, env)

    def tag_environment(self, name, annotated=False, target='HEAD'):
        # Only isolated TemporaryDirectory repositories receive fixture tags.
        if annotated:
            self.git('tag', '-a', name, target, '-m', 'TEST_FIXTURE_ONLY, never pushed')
        else:
            self.git('tag', name, target)
        ref = 'refs/tags/' + name
        after = self.git('rev-parse', ref).decode().strip()
        event = dict(before='0' * 40, after=after, ref=ref, created=True, deleted=False,
                     repository=dict(default_branch='main'))
        env = self.ci_environment('push', event)
        env.update(GITHUB_REF=ref, GITHUB_SHA=after)
        self.tag_env = env
        return event, env

    def test_ci_new_tags_check_target_commit_even_at_default_tip(self):
        for annotated in (False, True):
            for bad in (False, True):
                with self.subTest(annotated=annotated, bad=bad):
                    before = self.git('rev-parse', 'HEAD').decode().strip()
                    tip = self.successor('TEST_FIXTURE_ONLY bad \n' if bad else '# Clean tagged change\n')
                    self.git('update-ref', 'refs/remotes/origin/main', tip)
                    event, env = self.tag_environment(f'fixture-{annotated}-{bad}', annotated)
                    for context_sha in {event['after'], tip}:
                        env['GITHUB_SHA'] = context_sha
                        comparison = verify.ci_whitespace_range(self.root, env)
                        self.assertEqual((comparison['baseline'], comparison['target']), (before, tip))
                        self.assertEqual(comparison['event_after'], event['after'])
                        self.assertEqual(comparison['role'], 'INITIAL_TAG')
                        if bad:
                            with self.assertRaises(subprocess.CalledProcessError):
                                verify.whitespace_check(self.root, env)
                        else:
                            verify.whitespace_check(self.root, env)

    def checkout_tag_fixture(self, name, annotated=True, bad_whitespace=False):
        before = self.git('rev-parse', 'HEAD').decode().strip()
        tip = self.successor('TEST_FIXTURE_ONLY bad \n' if bad_whitespace else '# Checkout normalization fixture\n')
        event, env = self.tag_environment(name, annotated)
        raw = event['after']
        origin = Path(self.temp.name) / (name + '-origin.git')
        subprocess.run(['git', 'clone', '--bare', str(self.root), str(origin)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.git('remote', 'set-url', 'origin', str(origin))
        self.assertEqual(self.git('rev-parse', event['ref']).decode().strip(), raw)
        # Exact behavior observed in run 39880285031, in a temporary repo only.
        self.git('update-ref', event['ref'], tip, raw)
        self.assertEqual(self.git('rev-parse', event['ref']).decode().strip(), tip)
        return before, tip, raw, origin, event, env

    def test_ci_actions_checkout_annotated_tag_ref_normalization(self):
        before, tip, raw, _, event, env = self.checkout_tag_fixture('fixture-checkout-normalized')
        self.assertNotEqual(raw, tip)
        for after in (raw, tip):
            for context in (raw, tip):
                with self.subTest(event_after=after, github_sha=context):
                    Path(env['GITHUB_EVENT_PATH']).write_text(json.dumps(dict(event, after=after)))
                    comparison = verify.whitespace_check(self.root, dict(env, GITHUB_SHA=context))
                    self.assertEqual((comparison['baseline'], comparison['target']), (before, tip))

    def test_ci_actions_checkout_lightweight_tag_is_explicit(self):
        before, tip, raw, _, event, env = self.checkout_tag_fixture('fixture-lightweight', False)
        self.assertEqual(raw, tip)
        comparison = verify.whitespace_check(self.root, env)
        self.assertEqual(comparison['tag_identity']['object_type'], 'commit')
        self.assertEqual((comparison['baseline'], comparison['target']), (before, tip))

    def test_ci_actions_checkout_normalization_does_not_hide_whitespace(self):
        before, tip, _, _, _, env = self.checkout_tag_fixture('fixture-whitespace', bad_whitespace=True)
        self.assertEqual(verify.ci_whitespace_range(self.root, env)['baseline'], before)
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, env)

    def test_ci_normalized_tag_rejects_conflicting_raw_and_event_fields(self):
        before, tip, raw, _, event, env = self.checkout_tag_fixture('fixture-conflicts')
        self.git('tag', '-a', 'fixture-other-raw', tip, '-m', 'Same target, different raw object')
        other = self.git('rev-parse', 'refs/tags/fixture-other-raw').decode().strip()
        cases = [({'after': other}, {}), ({'after': before}, {}), ({'after': []}, {}),
                 ({'after': {}}, {}), ({}, {'GITHUB_SHA': other}), ({}, {'GITHUB_SHA': before}),
                 ({}, {'GITHUB_REF': 'refs/tags/wrong'}),
                 ({'ref': 'refs/tags/missing'}, {'GITHUB_REF': 'refs/tags/missing'}),
                 ({'created': False}, {}), ({'before': tip}, {}), ({'deleted': True}, {})]
        for changes, context in cases:
            with self.subTest(changes=changes, context=context):
                Path(env['GITHUB_EVENT_PATH']).write_text(json.dumps(dict(event, **changes)))
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    verify.whitespace_check(self.root, dict(env, **context))
        Path(env['GITHUB_EVENT_PATH']).write_text(json.dumps(event))
        self.git('update-ref', event['ref'], other)
        with self.assertRaisesRegex(ValueError, 'raw/peeled identity'):
            verify.whitespace_check(self.root, env)
        self.git('update-ref', event['ref'], tip)
        self.git('checkout', '--detach', before)
        with self.assertRaises(ValueError):
            verify.whitespace_check(self.root, env)

    def test_ci_normalized_tag_remote_failures_do_not_fallback(self):
        _, tip, raw, _, event, env = self.checkout_tag_fixture('fixture-remote-errors')
        real_git = verify.git
        valid = (raw + '\t' + event['ref'] + '\n' + tip + '\t' + event['ref'] + '^{}\n').encode()
        responses = [b'', valid + valid, b'not-a-sha\t' + event['ref'].encode(),
                     (raw + '\t' + event['ref'] + '\n').encode(),
                     valid + (tip + '\trefs/tags/extra\n').encode(),
                     subprocess.CalledProcessError(128, ['git', 'ls-remote']),
                     subprocess.TimeoutExpired(['git', 'ls-remote'], 60)]
        for response in responses:
            def remote(root, *args):
                if args[0] == 'ls-remote':
                    if isinstance(response, Exception):
                        raise response
                    return response
                return real_git(root, *args)
            with self.subTest(response=repr(response)), patch.object(verify, 'git', side_effect=remote):
                with self.assertRaises((ValueError, subprocess.SubprocessError)):
                    verify.whitespace_check(self.root, env)

    def test_ci_normalized_tag_missing_raw_object_and_shallow_parent_fail(self):
        before = self.git('rev-parse', 'HEAD').decode().strip()
        tip = self.successor('# Missing-object fixture\n')
        origin = Path(self.temp.name) / 'missing-object-origin.git'
        subprocess.run(['git', 'clone', '--bare', str(self.root), str(origin)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        clone = Path(self.temp.name) / 'missing-raw'
        subprocess.run(['git', 'clone', '--no-tags', '--depth', '1', '--no-local', str(origin), str(clone)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        # Create the raw object after cloning so transport cannot include it.
        event, _ = self.tag_environment('fixture-missing-object', True)
        raw = event['after']
        subprocess.run(['git', '-C', str(origin), 'fetch', str(self.root), event['ref'] + ':' + event['ref']],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        subprocess.run(['git', '-C', str(clone), 'update-ref', event['ref'], tip], check=True)
        env = self.ci_environment('push', event, clone)
        env.update(GITHUB_REF=event['ref'], GITHUB_SHA=tip)
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(clone, env)
        subprocess.run(['git', '-C', str(clone), 'fetch', '--depth', '1', '--no-tags', str(origin), raw],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        with self.assertRaisesRegex(ValueError, 'tag parent object'):
            verify.whitespace_check(clone, env)
        subprocess.run(['git', '-C', str(clone), 'fetch', '--unshallow', '--no-tags', 'origin'],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.assertEqual(verify.whitespace_check(clone, env)['baseline'], before)

    def run_normalized_tag_pipeline(self, env, mutate=None):
        # Real identity, whitespace, execute/log and final receipt validation;
        # only expensive build/history commands and toolchain are simulated.
        commands = {name: [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")'] for name in verify.REQUIRED}
        real_execute, real_output = verify.execute, subprocess.check_output
        def output(argv, *args, **kwargs):
            if argv in (['xcodebuild', '-version'], ['sw_vers', '-productVersion']):
                return b'TEST_FIXTURE_ONLY\n'
            return real_output(argv, *args, **kwargs)
        def execute(root, argv, log, timeout=1200):
            requested = argv
            if log.name in ('history-preparation.log', 'current-fixed-validator.log'):
                argv = [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")']
            if log.name == 'git_state.log':
                verify.whitespace_check(root, env)
            item = real_execute(root, argv, log, timeout); item['argv'] = requested
            if mutate and log.name == 'historical_progress.log':
                mutate()
            return item
        def summary(root, run, name):
            path = run / (name + '-summary.json')
            path.write_text(json.dumps(dict(totalTestCount=1, failedTests=0, skippedTests=0, result='Passed')))
            return dict(tests=1, failures=0, skips=0, result='Passed', summary=str(path.relative_to(root)),
                        summary_sha256=verify.sha(path.read_bytes()))
        with patch.object(verify, 'plan', return_value=commands), patch.object(verify, 'execute', side_effect=execute), \
             patch.object(verify, 'test_summary', side_effect=summary), patch.dict('os.environ', env), \
             patch.object(subprocess, 'check_output', side_effect=output):
            code = verify.run_all(self.root)
        data = json.loads((self.root / '.artifacts/v0.1.1-verification.json').read_text())
        return code, data, commands

    def test_ci_actions_checkout_normalized_tag_full_runner_and_receipt(self):
        _, tip, raw, _, event, env = self.checkout_tag_fixture('fixture-full-normalized')
        self.git('checkout', '--detach', tip)
        for after in (raw, tip):
            for context in (raw, tip):
                with self.subTest(event_after=after, github_sha=context):
                    Path(env['GITHUB_EVENT_PATH']).write_text(json.dumps(dict(event, after=after)))
                    active_env = dict(env, GITHUB_SHA=context)
                    code, data, commands = self.run_normalized_tag_pipeline(active_env)
                    self.assertEqual(code, 0); self.assertEqual(data['ci'], 'AUTOMATIC_JOB_CHECKS_PASS')
                    self.assertEqual(data['tag_identity']['raw'], raw)
                    self.assertEqual(data['tag_identity']['peeled'], tip)
                    self.assertEqual(set(data['checks']), set(verify.REQUIRED))
                    expected = verify.identity(self.root, ci=True)
                    verify.validate_receipt(self.root, data, expected, data['run_id'], commands)
                    for key in ('tag_identity', 'tag_event'):
                        bad = copy.deepcopy(data); del bad[key]
                        with self.assertRaisesRegex(ValueError, 'CI revision/result context'):
                            verify.validate_receipt(self.root, bad, expected, data['run_id'], commands)
                    bad = copy.deepcopy(data)
                    bad['ci_context']['GITHUB_SHA'] = tip
                    bad['ci_context']['GITHUB_REF'] = 'refs/tags/missing'
                    with self.assertRaisesRegex(ValueError, 'CI revision/result context'):
                        verify.validate_receipt(self.root, bad, expected, data['run_id'], commands)

    def test_ci_normalized_tag_final_receipt_rejects_same_target_remote_retag(self):
        _, tip, raw, origin, event, env = self.checkout_tag_fixture('fixture-drift')
        # A second raw object with the same internal name AND same target.
        body = self.git('cat-file', 'tag', raw).replace(b'TEST_FIXTURE_ONLY, never pushed', b'DIFFERENT raw fixture')
        other = subprocess.check_output(['git', '-C', str(self.root), 'mktag'], input=body).decode().strip()
        self.assertNotEqual(raw, other)
        subprocess.run(['git', '--git-dir', str(origin), 'fetch', '--no-tags', str(self.root), other],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        Path(env['GITHUB_EVENT_PATH']).write_text(json.dumps(dict(event, after=tip)))
        env = dict(env, GITHUB_SHA=tip)
        def retag():
            subprocess.run(['git', '--git-dir', str(origin), 'update-ref', event['ref'], other], check=True)
        code, data, _ = self.run_normalized_tag_pipeline(env, mutate=retag)
        self.assertEqual(code, 1); self.assertEqual(data['status'], 'FAIL')
        self.assertEqual(data['tag_identity']['raw'], raw)
        self.assertIn('tag event/remote identity changed', data['error'])

    def test_ci_root_tag_checks_full_tree(self):
        _, env = self.tag_environment('fixture-root', True)
        result = verify.whitespace_check(self.root, env)
        self.assertEqual(self.git('cat-file', 'tree', result['baseline']), b'')
        self.assertEqual(result['role'], 'INITIAL_TAG')

    def test_ci_tag_identity_and_noncreation_events_fail_closed(self):
        tip = self.successor('# Tag target\n')
        event, env = self.tag_environment('fixture-identity', True)
        self.git('tag', '-a', 'fixture-same-target', tip, '-m', 'Different TEST_FIXTURE_ONLY object')
        other = self.git('rev-parse', 'refs/tags/fixture-same-target').decode().strip()
        cases = [({'after': 'missing'}, {}), ({'after': '1' * 40}, {}),
                 ({'after': self.initial['git_revision']}, {}),
                 ({'ref': 'refs/tags/missing'}, {'GITHUB_REF': 'refs/tags/missing'}),
                 ({'ref': 'refs/tags/bad..name'}, {'GITHUB_REF': 'refs/tags/bad..name'}),
                 ({}, {'GITHUB_REF': 'refs/tags/other'}), ({}, {'GITHUB_REF': ''}),
                 ({}, {'GITHUB_SHA': other}), ({}, {'GITHUB_SHA': self.initial['git_revision']}),
                 ({'before': tip}, {}), ({'created': False}, {}), ({'created': 1}, {}),
                 ({'deleted': True}, {}), ({'deleted': None}, {})]
        for changes, context in cases:
            with self.subTest(changes=changes, context=context):
                payload = dict(event, **changes)
                bad_env = dict(env, **context)
                Path(bad_env['GITHUB_EVENT_PATH']).write_text(json.dumps(payload))
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    verify.whitespace_check(self.root, bad_env)

    def test_ci_tag_noncommit_targets_are_rejected(self):
        for target in ('HEAD^{tree}', 'HEAD:README.md'):
            with self.subTest(target=target):
                _, env = self.tag_environment('fixture-noncommit-' + str(len(target)), target=target)
                with self.assertRaises((ValueError, subprocess.CalledProcessError)):
                    verify.whitespace_check(self.root, env)

    def test_ci_shallow_tag_requires_real_parent_object(self):
        before = self.initial['git_revision']; tip = self.successor('TEST_FIXTURE_ONLY bad \n')
        event, _ = self.tag_environment('fixture-shallow', True)
        clone = Path(self.temp.name) / 'shallow-tag'
        subprocess.run(['git', 'clone', '--depth', '1', '--branch', 'fixture-shallow', '--no-local',
                        str(self.root), str(clone)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        env = self.ci_environment('push', event, clone)
        env.update(GITHUB_REF=event['ref'], GITHUB_SHA=event['after'])
        with self.assertRaisesRegex(ValueError, 'tag parent object'):
            verify.whitespace_check(clone, env)
        subprocess.run(['git', '-C', str(clone), 'fetch', '--depth', '1', '--no-tags', str(self.root), before],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.assertEqual(verify.ci_whitespace_range(clone, env)['target'], tip)
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(clone, env)

    def test_ci_tag_receipt_accepts_exact_raw_or_peeled_identity_only(self):
        event, env = self.tag_environment('fixture-receipt', True)
        self.initial = verify.identity(self.root, ci=True)
        data = self.receipt(); data.update(ci='RUNNING', ci_context=env)
        self.validate(data)
        data['ci_context'] = dict(env, GITHUB_SHA=self.initial['git_revision'])
        self.validate(data)
        self.git('tag', '-a', 'fixture-receipt-other', '-m', 'Different TEST_FIXTURE_ONLY object')
        other = self.git('rev-parse', 'refs/tags/fixture-receipt-other').decode().strip()
        for changes in ({'GITHUB_SHA': other}, {'GITHUB_REF': 'refs/heads/fixture-feature'},
                        {'GITHUB_REF': ''}, {'GITHUB_EVENT_NAME': 'pull_request'}):
            data['ci_context'] = dict(env, **changes)
            with self.subTest(changes=changes), self.assertRaisesRegex(ValueError, 'CI revision/result context'):
                self.validate(data)

    def test_ci_tag_runner_retains_raw_identity(self):
        event, env = self.tag_environment('fixture-runner', True)
        commands = {name: [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")'] for name in verify.REQUIRED}
        real_output = subprocess.check_output
        def output(argv, *args, **kwargs):
            if argv in (['xcodebuild', '-version'], ['sw_vers', '-productVersion']):
                return b'TEST_FIXTURE_ONLY\n'
            return real_output(argv, *args, **kwargs)
        # Exercise actual tag whitespace validation and receipt, simulating only
        # expensive build/history commands as existing runner fixtures do.
        real_execute = verify.execute
        def execute(root, argv, log, timeout=1200):
            requested_argv = argv
            if log.name in ('history-preparation.log', 'current-fixed-validator.log'):
                argv = [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")']
            if log.name == 'git_state.log':
                verify.whitespace_check(root, env)
            item = real_execute(root, argv, log, timeout)
            # Simulated history command identity only; production execute and
            # receipt validation remain exact and are not bypassed.
            item['argv'] = requested_argv
            return item
        def summary(root, run, name):
            p = run / (name + '-summary.json')
            p.write_text(json.dumps(dict(totalTestCount=1, failedTests=0, skippedTests=0, result='Passed')))
            return dict(tests=1, failures=0, skips=0, result='Passed', summary=str(p.relative_to(root)),
                        summary_sha256=verify.sha(p.read_bytes()))
        with patch.object(verify, 'plan', return_value=commands), patch.object(verify, 'execute', side_effect=execute), \
             patch.object(verify, 'test_summary', side_effect=summary), patch.dict('os.environ', env), \
             patch.object(subprocess, 'check_output', side_effect=output):
            self.assertEqual(verify.run_all(self.root), 0)
        data = json.loads((self.root / '.artifacts/v0.1.1-verification.json').read_text())
        self.assertEqual(data['ci_context']['GITHUB_SHA'], event['after'])
        self.assertEqual(data['ci_context']['GITHUB_REF'], event['ref'])
        self.assertEqual(data['identity']['git_revision'], self.initial['git_revision'])
        self.assertEqual(data['ci'], 'AUTOMATIC_JOB_CHECKS_PASS')

    def test_ci_initial_feature_push_uses_default_merge_base(self):
        before = self.initial['git_revision']; tip = self.successor('TEST_FIXTURE_ONLY bad \n')
        self.git('update-ref', 'refs/remotes/origin/main', before)
        event = dict(before='0' * 40, after=tip, ref='refs/heads/fixture-feature', repository=dict(default_branch='main'))
        env = self.ci_environment('push', event)
        self.assertEqual(verify.ci_whitespace_range(self.root, env)['baseline'], before)
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, env)
        self.git('update-ref', '-d', 'refs/remotes/origin/main')
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, env)

    def test_ci_initial_default_branch_push_checks_full_tree(self):
        tip = self.successor('TEST_FIXTURE_ONLY bad \n'); self.git('update-ref', 'refs/remotes/origin/main', tip)
        event = dict(before='0' * 40, after=tip, ref='refs/heads/main', repository=dict(default_branch='main'))
        env = self.ci_environment('push', event)
        self.assertEqual(verify.ci_whitespace_range(self.root, env)['role'], 'INITIAL_DEFAULT_BRANCH')
        with self.assertRaises(subprocess.CalledProcessError):
            verify.whitespace_check(self.root, env)

    def test_readme_change_beyond_legacy_fingerprint_rejected(self):
        (self.root / 'README.md').write_text('changed docs')
        self.assertEqual(verify.fingerprint(self.root), self.initial['source_fingerprint'])
        with self.assertRaisesRegex(ValueError, 'inputs changed'):
            verify.assert_unchanged(self.root, self.initial)

    def test_untracked_staged_committed_workflow_and_markdown_inputs(self):
        for name in ('new.md', '.github/workflows/new.yml'):
            p = self.root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text('new input')
            before = verify.identity(self.root)
            self.assertIn(name, before['untracked_paths'])
            self.assertIn(name, before['inputs'])
            self.git('add', name)
            with self.assertRaisesRegex(ValueError, 'inputs changed'):
                verify.assert_unchanged(self.root, before)
            staged = verify.identity(self.root)
            self.git('commit', '-qm', 'isolated added-input fixture')
            self.assertIn(name, verify.identity(self.root)['inputs'])
            with self.assertRaisesRegex(ValueError, 'inputs changed'):
                verify.assert_unchanged(self.root, staged)

    def test_delete_mode_and_symlink_changes_rejected(self):
        p = self.root / 'README.md'
        for scenario in ('mode', 'delete', 'symlink'):
            if p.exists() or p.is_symlink():
                p.unlink()
            p.write_text('# Fixture\n'); p.chmod(0o644); initial = verify.identity(self.root)
            if scenario == 'mode':
                p.chmod(0o755)
            elif scenario == 'delete':
                p.unlink()
            else:
                p.unlink(); p.symlink_to('MacSoul/input.swift')
            with self.assertRaisesRegex(ValueError, 'inputs changed'):
                verify.assert_unchanged(self.root, initial)

    def test_ci_clean_checkout_and_detached_head(self):
        self.assertEqual(verify.identity(self.root, ci=True)['checkout_kind'], 'CI_CLEAN')
        self.git('checkout', '--detach')
        self.assertEqual(verify.identity(self.root, ci=True)['branch'], 'DETACHED')
        (self.root / 'README.md').write_text('dirty')
        with self.assertRaisesRegex(ValueError, 'must remain clean'):
            verify.identity(self.root, ci=True)

    def test_shallow_checkout_without_main_or_artifacts(self):
        clone = Path(self.temp.name) / 'shallow'
        subprocess.run(['git', 'clone', '--depth', '1', '--no-local', str(self.root), str(clone)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
        self.assertEqual(verify.identity(clone, ci=True)['git_revision'], self.initial['git_revision'])
        self.assertFalse((clone / '.artifacts').exists())
        self.assertEqual(verify.git(clone, 'branch', '--list', 'main'), b'')
        self.assertFalse((clone / '.git/objects/info/alternates').exists())
        subprocess.run(['git', '-C', str(clone), 'checkout', '--detach'], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.assertEqual(verify.identity(clone, ci=True)['branch'], 'DETACHED')

    def test_shallow_source_uses_complete_fixed_closure_in_fresh_repository(self):
        evidence = self.root / 'docs/evidence'; evidence.mkdir()
        decision = evidence / 'v0.1.0-owner-decision.json'
        decision.write_text('{"scope":"TEST_FIXTURE_ONLY, not Owner approval"}\n')
        self.git('add', 'docs/evidence/v0.1.0-owner-decision.json')
        self.git('commit', '-qm', 'isolated successor fixture, never pushed')
        revision = self.git('rev-parse', 'HEAD').decode().strip()
        tree = self.git('rev-parse', 'HEAD^{tree}').decode().strip()
        clone = Path(self.temp.name) / 'shallow-source'
        subprocess.run(['git', 'clone', '--depth', '1', '--no-local', str(self.root), str(clone)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        # Test-only source substitutes a complete LOCAL fixture for public Git;
        # the production branch still uses its fixed, reviewed HTTPS repository.
        frozen = Path(self.temp.name) / 'fixed-closure'
        with patch.object(verify, 'PUBLIC_GIT', str(self.root)), patch.object(verify, 'FIXED_OBJECTS', (revision,)), \
             patch.object(verify, 'HISTORICAL', revision), patch.object(verify, 'HISTORICAL_TREE', tree), \
             patch.object(verify, 'HISTORICAL_FP', verify.fingerprint(self.root)), \
             patch.object(verify, 'HISTORICAL_DECISION', verify.sha(decision.read_bytes())):
            verify.historical_checkout(clone, frozen)
        self.assertEqual(verify.git(frozen, 'rev-parse', '--is-shallow-repository').strip(), b'false')
        self.assertEqual(verify.git(frozen, 'rev-parse', 'HEAD^').decode().strip(), self.initial['git_revision'])
        self.assertFalse((frozen / '.git/objects/info/alternates').exists())
        self.assertFalse((frozen / '.artifacts').exists())

    def test_owned_command_failure_and_start_failure_capture(self):
        for name, argv, code in (('unit', [sys.executable, '-c', 'print("unit failed"); raise SystemExit(65)'], 65),
                                 ('build', [sys.executable, '-c', 'print("build failed"); raise SystemExit(1)'], 1),
                                 ('absent', [str(self.root / 'missing-executable')], 127)):
            item = verify.execute(self.root, argv, self.run / (name + '-failure.log'))
            self.assertEqual(item['exit_code'], code); self.assertEqual(item['status'], 'FAIL')
            self.assertEqual(item['log_sha256'], verify.sha((self.root / item['log']).read_bytes()))

    def test_fresh_log_cannot_be_overwritten(self):
        log = self.run / 'existing.log'; log.write_text('old result')
        with self.assertRaises(FileExistsError):
            verify.execute(self.root, [sys.executable, '-c', 'print("new")'], log)
        self.assertEqual(log.read_text(), 'old result')

    def test_missing_history_objects_do_not_use_local_cache_or_implicit_network(self):
        # ensure_objects performs a declared fetch; the offline historical action
        # and integrity readers never fetch a moving branch to hide missing SHA.
        missing = '0' * 40
        with self.assertRaisesRegex(ValueError, 'missing fixed historical object'):
            verify.require_object(self.root, missing)
        verify.require_object(self.root, self.initial['git_revision'])
        result = subprocess.run([sys.executable, str(verify.ROOT / 'scripts/verify_v011.py'), 'history'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('missing/wrong fixed historical checkout', result.stderr)

    def test_runner_propagates_actual_build_and_unit_failure(self):
        for failed in ('build', 'unit'):
            with self.subTest(failed=failed):
                commands = {name: [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY"); raise SystemExit(' +
                                  ('65' if name == failed else '0') + ')'] for name in verify.REQUIRED}
                real_execute = verify.execute
                def execute(root, argv, log, timeout=1200):
                    # Only historical preparation/diagnostic are simulated here;
                    # build/unit command failures run and are captured for real.
                    if log.name == 'history-preparation.log':
                        argv = [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY historical preparation")']
                    elif log.name == 'current-fixed-validator.log':
                        argv = [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY fixed-scope refusal"); raise SystemExit(1)']
                    return real_execute(root, argv, log, timeout)
                def summary(root, run, name):
                    p = run / (name + '-summary.json')
                    p.write_text(json.dumps(dict(totalTestCount=1, failedTests=1 if name == failed else 0,
                                                skippedTests=0, result='Failed' if name == failed else 'Passed')))
                    return dict(tests=1, failures=1 if name == failed else 0, skips=0,
                                result='Failed' if name == failed else 'Passed', summary=str(p.relative_to(root)),
                                summary_sha256=verify.sha(p.read_bytes()))
                with patch.object(verify, 'plan', return_value=commands), patch.object(verify, 'execute', side_effect=execute), \
                     patch.object(verify, 'test_summary', side_effect=summary), patch.dict('os.environ', {'GITHUB_ACTIONS': 'false'}):
                    self.assertEqual(verify.run_all(self.root), 1)
                receipt = json.loads((self.root / '.artifacts/v0.1.1-verification.json').read_text())
                self.assertEqual(receipt['status'], 'FAIL')
                self.assertEqual(receipt['checks'][failed]['exit_code'], 65)
                self.assertIn('required check failed: ' + failed, receipt['error'])
                self.assertEqual(receipt['ci'], 'NOT_RUN')

    def test_current_progress_missing_dependency_and_plan_rejected(self):
        for path in ('tasks.json', 'docs/7-DAY-PLAN.md', 'docs/STATUS.md', 'scripts/generate_status.py'):
            shutil.copyfile(verify.ROOT / path, self.root / path)
        data = json.loads((self.root / 'tasks.json').read_text()); data['tasks'][0]['depends_on'] = ['UNKNOWN']
        (self.root / 'tasks.json').write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, 'status/dependency'):
            verify.current_progress(self.root)
        shutil.copyfile(verify.ROOT / 'tasks.json', self.root / 'tasks.json')
        (self.root / 'docs/7-DAY-PLAN.md').write_text('changed original plan')
        with self.assertRaisesRegex(ValueError, 'plan content changed'):
            verify.current_progress(self.root)

    def test_complete_patch_contains_untracked_input_and_applies_to_clean_fixture(self):
        p = self.root / 'scripts/new-verifier.py'; p.write_text('# isolated new input\n'); p.chmod(0o755)
        raw = verify.candidate_patch(self.root)
        self.assertIn(b'new file mode 100755', raw)
        self.assertIn(b'b/scripts/new-verifier.py', raw)
        clone = Path(self.temp.name) / 'patch-clone'
        subprocess.run(['git', 'clone', '--depth', '1', '--no-local', str(self.root), str(clone)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        subprocess.run(['git', '-C', str(clone), 'apply', '--check', '-'], input=raw, check=True)
        subprocess.run(['git', '-C', str(clone), 'apply', '-'], input=raw, check=True)
        self.assertEqual(verify.file_identity(p), verify.file_identity(clone / 'scripts/new-verifier.py'))

    def test_run_detects_input_mutation_and_retains_failed_receipt(self):
        commands = {name: [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")'] for name in verify.REQUIRED}
        commands['doctor'] = [sys.executable, '-c', 'from pathlib import Path; Path("README.md").write_text("mutated")']
        real_execute = verify.execute
        def execute(root, argv, log, timeout=1200):
            if log.name in ('history-preparation.log', 'current-fixed-validator.log'):
                argv = [sys.executable, '-c', 'print("TEST_FIXTURE_ONLY")']
            return real_execute(root, argv, log, timeout)
        with patch.object(verify, 'plan', return_value=commands), patch.object(verify, 'execute', side_effect=execute), \
             patch.dict('os.environ', {'GITHUB_ACTIONS': 'false'}):
            self.assertEqual(verify.run_all(self.root), 1)
        data = json.loads((self.root / '.artifacts/v0.1.1-verification.json').read_text())
        self.assertIn('inputs changed', data['error'])
        self.assertIn('unit', data['not_run_checks'])
        self.assertEqual(data['checks']['doctor']['exit_code'], 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
