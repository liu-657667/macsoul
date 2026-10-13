#!/usr/bin/env python3
"""v0.1.1 automatic verification, separate from fixed v0.1.0 acceptance.

Receipts attest recorded command results and input consistency, not Owner identity
or human acceptance. Every run owns fresh logs; historical checks use frozen Git
objects, never a historical approval applied to current product changes.
"""
import argparse
import collections
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from urllib.parse import unquote, urlsplit
import uuid

ROOT = Path(__file__).resolve().parent.parent
HISTORICAL = 'd5084ba95d648bb3bc4a1c4975318e9cb822e4b8'
HISTORICAL_TREE = '84f44f5ccd12666e441192306ec3f4a9227ac01a'
HISTORICAL_FP = '80332822221eba5e377f360a51cbbc15307eceeb5070552687c45e3035aca7a0'
HISTORICAL_DECISION = '08a954fed4838c6f865b93528941ed14906f87e9e8b813bd32cc1d3036c7fed3'
FIXED_OBJECTS = (HISTORICAL, 'b7ca041e0a07623113534e577301f7c3c313df26',
                 '51f0c0d3a1361ac5ac7ceac52b84175f71ff78e0')
PUBLIC_GIT = 'https://github.com/liu-657667/macsoul.git'
SCHEMA = 'macsoul-v0.1.1-verification/1'
UNEXECUTED = dict(manual_ui='NOT_RUN', live_provider='NOT_RUN', performance='NOT_RUN',
                  owner_ui='PENDING_OWNER', owner_live='PENDING_OWNER', packaging='NOT_RUN',
                  signing='NOT_RUN', notarization='NOT_RUN', publication='NOT_RUN')
REQUIRED = ('doctor', 'build', 'network', 'unit', 'script_tests', 'visual_assets',
            'current_progress', 'docs', 'git_state', 'historical_integrity', 'historical_progress')
DOCUMENTS = ('README.md', 'README.en.md', 'docs/ARCHITECTURE.md', 'docs/DEVELOPMENT.md',
             'scripts/README.md', 'docs/STATUS.md')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def git(root, *args):
    return subprocess.check_output(['git', '--no-replace-objects', '-C', str(root), *args],
                                   stderr=subprocess.PIPE, timeout=60)


def now():
    return datetime.now(timezone.utc).isoformat()


def fingerprint(root):
    paths = [p for folder in ('MacSoul', 'MacSoulTests', 'MacSoul.xcodeproj', 'scripts')
             for p in (root / folder).rglob('*') if p.is_file()
             and 'xcuserdata' not in p.parts and '__pycache__' not in p.parts and p.suffix != '.pyc']
    paths += [root / p for p in ('docs/DESIGN.md', 'docs/SCOPE.md') if (root / p).exists()]
    h = hashlib.sha256()
    for p in sorted(paths):
        h.update(str(p.relative_to(root)).encode() + b'\0' + p.read_bytes() + b'\0')
    return h.hexdigest()


def file_identity(path):
    if not path.exists() and not path.is_symlink():
        return {'type': 'missing'}
    mode = path.lstat().st_mode
    if stat.S_ISLNK(mode):
        return {'type': 'symlink', 'mode': '120000', 'sha256': sha(os.readlink(path).encode())}
    if not stat.S_ISREG(mode):
        raise ValueError('unsupported verification input type')
    return {'type': 'file', 'mode': '100755' if mode & 0o111 else '100644',
            'bytes': path.stat().st_size, 'sha256': sha(path.read_bytes())}


def candidate_patch(root):
    paths = set(git(root, 'diff', '--name-only', 'HEAD', '--').decode().splitlines())
    new = set(git(root, 'ls-files', '--others', '--exclude-standard', '-z').decode().rstrip('\0').split('\0')) - {''}
    parts = []
    for path in sorted(paths | new):
        if path in new:
            result = subprocess.run(['git', 'diff', '--no-index', '--binary', '--full-index',
                                     '--', '/dev/null', path], cwd=root, capture_output=True, timeout=60)
            if result.returncode not in (0, 1):
                raise ValueError('cannot describe new candidate input: ' + path)
            parts.append(result.stdout)
        else:
            parts.append(git(root, 'diff', '--binary', '--full-index', 'HEAD', '--', path))
    return b''.join(parts)


def identity(root, ci=False):
    # Union includes committed/index additions/deletions and nonignored untracked
    # docs/workflow/scripts. Legacy ignored fingerprint inputs are also covered.
    tracked = set(git(root, 'ls-files', '-z').decode().rstrip('\0').split('\0')) - {''}
    untracked = set(git(root, 'ls-files', '--others', '--exclude-standard', '-z').decode().rstrip('\0').split('\0')) - {''}
    legacy = {str(p.relative_to(root)) for folder in ('MacSoul', 'MacSoulTests', 'MacSoul.xcodeproj', 'scripts')
              for p in (root / folder).rglob('*') if p.is_file()
              and 'xcuserdata' not in p.parts and '__pycache__' not in p.parts and p.suffix != '.pyc'}
    status = git(root, 'status', '--porcelain=v1', '-z').decode()
    index = git(root, 'ls-files', '--stage', '-z').decode()
    if any(line.split('\t', 1)[0].split()[-1] != '0' for line in index.rstrip('\0').split('\0') if line):
        raise ValueError('unmerged index')
    if ci and status:
        raise ValueError('CI checkout must remain clean')
    entries = {p: file_identity(root / p) for p in sorted(tracked | untracked | legacy)}
    extra_ignored = legacy - tracked - untracked
    if ci and extra_ignored:
        raise ValueError('undeclared ignored fingerprint inputs in CI: ' + ', '.join(sorted(extra_ignored)))
    patch = candidate_patch(root)
    # Both patch and complete input inventory include new untracked files;
    # index identity remains separate from the target working-tree contents.
    return {'git_revision': git(root, 'rev-parse', 'HEAD').decode().strip(),
            'git_tree': git(root, 'rev-parse', 'HEAD^{tree}').decode().strip(),
            'branch': git(root, 'symbolic-ref', '--short', '-q', 'HEAD').decode().strip()
                      if subprocess.run(['git', '-C', str(root), 'symbolic-ref', '-q', 'HEAD'],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0 else 'DETACHED',
            'checkout_kind': 'CI_CLEAN' if ci else ('LOCAL_DIRTY' if status else 'LOCAL_CLEAN'),
            'source_fingerprint': fingerprint(root), 'patch_sha256': sha(patch),
            'index_sha256': sha(index.encode()), 'status_sha256': sha(status.encode()),
            'untracked_paths': sorted(untracked), 'inputs': entries,
            'inputs_sha256': sha(canonical(entries))}


def assert_unchanged(root, initial, ci=False):
    actual = identity(root, ci)
    if actual != initial:
        changed = sorted(p for p in initial['inputs'].keys() | actual['inputs'].keys()
                         if initial['inputs'].get(p) != actual['inputs'].get(p))
        raise ValueError('verification inputs changed; rerun affected checks: ' + ', '.join(changed))


def execute(root, argv, log, timeout=1200):
    """Capture actual failures and timeout; terminate only this owned process group."""
    started = now()
    with log.open('xb') as output:
        output.write(('argv=' + json.dumps(argv) + '\n').encode()); output.flush()
        try:
            process = subprocess.Popen(argv, cwd=root, stdout=output, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                output.write(b'OWNED_COMMAND_TIMEOUT\n'); output.flush()
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL); process.wait()
                code = 124
        except OSError as error:
            output.write(('COMMAND_START_FAILURE: ' + str(error) + '\n').encode()); code = 127
    return {'argv': argv, 'started_at': started, 'ended_at': now(), 'exit_code': code,
            'status': 'PASS' if code == 0 else 'FAIL', 'log': str(log.relative_to(root)),
            'log_sha256': sha(log.read_bytes())}


def require_object(root, revision):
    """Offline exact-object check; missing objects do not silently become PASS."""
    try:
        commit = git(root, 'cat-file', 'commit', revision)
        actual = hashlib.sha1(b'commit ' + str(len(commit)).encode() + b'\0' + commit).hexdigest()
        if actual != revision:
            raise ValueError('fixed commit bytes mismatch: ' + revision)
        git(root, 'cat-file', '-e', revision + '^{tree}')
    except subprocess.CalledProcessError as error:
        raise ValueError('missing fixed historical object: ' + revision) from error


def historical_checkout(root, destination):
    # A fresh empty repository avoids Git's exit-0 rejected shallow-root update.
    # The unchanged historical suite itself clones fixtures, so its source needs
    # the complete closure of these fixed commits (not current/moving history).
    destination.mkdir(parents=True, exist_ok=False)
    subprocess.run(['git', '-C', str(destination), 'init', '-q'], check=True)
    shallow = git(root, 'rev-parse', '--is-shallow-repository').decode().strip() == 'true'
    source = PUBLIC_GIT if shallow else str(root)
    if not shallow:
        try:
            for revision in FIXED_OBJECTS:
                require_object(root, revision)
            git(root, 'rev-list', '--objects', '--missing=error', *FIXED_OBJECTS)
        except (ValueError, subprocess.CalledProcessError):
            source = PUBLIC_GIT
    print('Explicit fixed historical closure source: ' + source, flush=True)
    for revision in FIXED_OBJECTS:
        subprocess.run(['git', '-C', str(destination), 'fetch', '--no-tags', source, revision],
                       check=True, timeout=120)
        if git(destination, 'rev-parse', revision + '^{commit}').decode().strip() != revision:
            raise ValueError('missing/mismatched historical object: ' + revision)
        require_object(destination, revision)
    git(destination, 'rev-list', '--objects', '--missing=error', *FIXED_OBJECTS)
    if git(destination, 'rev-parse', '--is-shallow-repository').decode().strip() != 'false':
        raise ValueError('fixed historical closure is incomplete/shallow')
    if (destination / '.git/objects/info/alternates').exists():
        raise ValueError('historical checkout must not share objects')
    subprocess.run(['git', '-C', str(destination), 'checkout', '--detach', HISTORICAL], check=True)
    if git(destination, 'rev-parse', 'HEAD^{tree}').decode().strip() != HISTORICAL_TREE:
        raise ValueError('historical tree mismatch')
    if fingerprint(destination) != HISTORICAL_FP:
        raise ValueError('historical fingerprint mismatch')
    if sha((destination / 'docs/evidence/v0.1.0-owner-decision.json').read_bytes()) != HISTORICAL_DECISION:
        raise ValueError('historical Owner decision mismatch')


def historical_integrity(root, frozen):
    protected = ('tasks.json', 'docs/7-DAY-PLAN.md', 'scripts/fingerprint.py', 'scripts/verify.sh',
                 'scripts/verify_doc_maintenance.py', 'scripts/verify_progress.py', 'scripts/test_progress.py')
    paths = set(protected)
    for prefix in ('reports/', 'docs/evidence/', 'docs/archive/'):
        old_paths = {p for p in git(frozen, 'ls-files', '-z').decode().split('\0') if p.startswith(prefix)}
        current_paths = {p for p in git(root, 'ls-files', '-z').decode().split('\0') if p.startswith(prefix)}
        current_paths |= {p for p in git(root, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0') if p.startswith(prefix)}
        if old_paths != current_paths:
            raise ValueError('historical path set changed: ' + prefix)
        paths |= old_paths
    for path in sorted(paths):
        if file_identity(root / path) != file_identity(frozen / path):
            raise ValueError('historical bytes/mode changed: ' + path)
    subprocess.run([sys.executable, 'scripts/verify_doc_maintenance.py', 'check'], cwd=frozen, check=True)
    print(json.dumps({'historical_revision': HISTORICAL, 'historical_tree': HISTORICAL_TREE,
                      'historical_fingerprint': HISTORICAL_FP, 'owner_decision_sha256': HISTORICAL_DECISION,
                      'preserved_paths': len(paths), 'scope': 'history preservation, NOT current product acceptance'}))


def current_progress(root):
    # Structural invariants and deterministic generation only. Historical done
    # evidence is not transferred to the changed product fingerprint.
    data = json.loads((root / 'tasks.json').read_text())
    tasks = data['tasks']; ids = {t['id'] for t in tasks}
    if len(ids) != len(tasks):
        raise ValueError('duplicate task IDs')
    states = {'todo', 'doing', 'blocked', 'verifying', 'done', 'deferred'}
    baseline = root / data['baseline']['source']
    if not baseline.is_file() or sha(baseline.read_bytes()) != data['baseline']['sha256']:
        raise ValueError('original plan content changed')
    for task in tasks:
        if task['status'] not in states or not set(task.get('depends_on', [])) <= ids:
            raise ValueError('invalid task status/dependency: ' + task['id'])
        if task['original_points'] != task['current_points'] and not task.get('scope_change_approval'):
            raise ValueError('unapproved point change: ' + task['id'])
        if task['status'] in ('blocked', 'deferred') and not task.get('blocker'):
            raise ValueError('missing blocker reason: ' + task['id'])
        if task['status'] == 'deferred' and not task.get('scope_change_approval'):
            raise ValueError('unapproved deferral: ' + task['id'])
        if task['status'] == 'done':
            accepts = {a['id'] for a in task.get('acceptance', [])}
            covered = {e.get('acceptance_id') for e in task.get('evidence', [])}
            if not accepts <= covered:
                raise ValueError('uncovered historical acceptance: ' + task['id'])
            if any(a['kind'] == 'manual-ui' for a in task.get('acceptance', [])) and not task.get('human_ui_confirmation'):
                raise ValueError('missing historical human flag: ' + task['id'])
    original = [t for t in tasks if t['original_day'] is not None]
    if len(original) != 48 or any(t['status'] != 'done' for t in original):
        raise ValueError('original accepted task states changed')
    if sum(t['original_points'] for t in original) != 76 or data['baseline']['original_points'] != 76:
        raise ValueError('original denominator changed')
    counts = collections.Counter(t['status'] for t in tasks)
    if len(tasks) != 59 or counts != {'done': 51, 'verifying': 8}:
        raise ValueError('historical increment states changed')
    with tempfile.TemporaryDirectory(prefix='macsoul-v011-status-') as directory:
        copy = Path(directory); (copy / 'scripts').mkdir(); (copy / 'docs').mkdir()
        shutil.copyfile(root / 'tasks.json', copy / 'tasks.json')
        shutil.copyfile(root / 'scripts/generate_status.py', copy / 'scripts/generate_status.py')
        for _ in range(2):
            subprocess.run([sys.executable, str(copy / 'scripts/generate_status.py')], check=True)
            if (copy / 'docs/STATUS.md').read_bytes() != (root / 'docs/STATUS.md').read_bytes():
                raise ValueError('generator/STATUS mismatch')
    print(json.dumps({'tasks': len(tasks), 'original_done': 48, 'original_points': 76,
                      'done': 51, 'historical_verifying': 8, 'generator': 'PASS',
                      'scope': 'current readonly structure; no new task acceptance'}))


def anchors(text):
    counts = collections.Counter(); result = set()
    for line in text.splitlines():
        if re.match(r'^#{1,6} ', line):
            value = re.sub(r'\[([^]]+)\]\([^)]*\)', r'\1', line.lstrip('# ').strip()).lower()
            value = re.sub(r'[^\w\-\s]', '', value).replace(' ', '-')
            count = counts[value]; counts[value] += 1
            result.add(value + (f'-{count}' if count else ''))
    return result


def documents(root):
    # Scope is explicit plus every changed/untracked Markdown input; history is
    # preserved independently, not mechanically rewritten or re-audited.
    names = set(DOCUMENTS)
    names |= {p for p in git(root, 'diff', '--name-only', 'HEAD', '--').decode().splitlines() if p.endswith('.md')}
    names |= {p for p in git(root, 'ls-files', '--others', '--exclude-standard').decode().splitlines() if p.endswith('.md')}
    links = fragments = 0
    for name in sorted(names):
        text = re.sub(r'```[\s\S]*?```', '', (root / name).read_text())
        for raw in re.findall(r'!?\[[^]\n]*\]\(([^)]+)\)', text):
            url = urlsplit(raw.strip().strip('<>'))
            if url.scheme or raw.startswith('//'):
                continue
            target = (root / name).parent / unquote(url.path) if url.path else root / name
            if not target.resolve().is_relative_to(root.resolve()) or not target.is_file():
                raise ValueError('missing/outside local document link in ' + name)
            links += 1
            if url.fragment:
                fragments += 1
                if unquote(url.fragment) not in anchors(target.read_text()):
                    raise ValueError('missing document fragment in ' + name + ': ' + url.fragment)
    for name in ('README.md', 'README.en.md', 'docs/ARCHITECTURE.md'):
        text = (root / name).read_text()
        if not ('IPinfo' in text and 'ident.me' in text):
            raise ValueError('current Network source explanation missing: ' + name)
    print(json.dumps({'documents': sorted(names), 'local_links': links, 'fragments': fragments,
                      'external_links': 'syntax only; no live HTTP requests'}))


def ci_whitespace_range(root, environment):
    """Resolve event-specific immutable inputs; never substitute HEAD for a base."""
    head = git(root, 'rev-parse', 'HEAD').decode().strip()
    if environment.get('GITHUB_SHA') != head:
        raise ValueError('CI whitespace checkout/event SHA mismatch')
    event_path = environment.get('GITHUB_EVENT_PATH')
    if not event_path:
        raise ValueError('missing CI event payload for whitespace baseline')
    event = json.loads(Path(event_path).read_text())
    def commit(value, label):
        if not isinstance(value, str) or not re.fullmatch(r'[0-9a-f]{40}', value):
            raise ValueError('invalid CI whitespace ' + label + ' SHA')
        try:
            require_object(root, value)
        except ValueError as error:
            raise ValueError('missing/invalid CI whitespace ' + label + ' object: ' + value) from error
        return value
    kind = environment.get('GITHUB_EVENT_NAME')
    if kind == 'pull_request':
        pr = event.get('pull_request', {})
        base = commit(pr.get('base', {}).get('sha'), 'PR base')
        tip = commit(pr.get('head', {}).get('sha'), 'PR head')
        if head == tip:
            # Explicit PR head checkout: the branch's changes from divergence.
            baseline = git(root, 'merge-base', base, tip).decode().strip()
            commit(baseline, 'PR merge base')
            return {'event': kind, 'role': 'PR_HEAD', 'baseline': baseline, 'target': head,
                    'event_base': base, 'event_head': tip}
        # cat-file retains true parents even in a depth1 synthetic checkout.
        parents = [line[7:] for line in git(root, 'cat-file', 'commit', head).decode().split('\n\n', 1)[0].splitlines()
                   if line.startswith('parent ')]
        if parents != [base, tip]:
            raise ValueError('CI synthetic merge parents do not match PR base/head')
        return {'event': kind, 'role': 'PR_SYNTHETIC_MERGE', 'baseline': base, 'target': head,
                'event_base': base, 'event_head': tip}
    if kind == 'push':
        if commit(event.get('after'), 'push after') != head:
            raise ValueError('CI push after does not match checkout')
        before = event.get('before')
        if before != '0' * 40:
            return {'event': kind, 'role': 'PUSH_RANGE', 'baseline': commit(before, 'push before'), 'target': head}
        # Newly created feature ref has no before commit. Compare its changes
        # from the fetched default branch, recording that actual observed tip.
        default = event.get('repository', {}).get('default_branch')
        if not isinstance(default, str) or not default:
            raise ValueError('missing default branch for initial-push whitespace baseline')
        ref = 'refs/remotes/origin/' + default
        git(root, 'check-ref-format', ref)
        default_tip = commit(git(root, 'rev-parse', '--verify', ref + '^{commit}').decode().strip(), 'default branch')
        pushed_ref = event.get('ref')
        if not isinstance(pushed_ref, str) or not pushed_ref.startswith('refs/heads/'):
            raise ValueError('unsupported initial-push ref for whitespace baseline')
        if pushed_ref == 'refs/heads/' + default:
            # First push of the default branch introduces the entire tree.
            baseline = subprocess.check_output(['git', '-C', str(root), 'hash-object', '-w', '-t', 'tree', '--stdin'],
                                               input=b'', timeout=60).decode().strip()
            return {'event': kind, 'role': 'INITIAL_DEFAULT_BRANCH', 'baseline': baseline, 'target': head}
        baseline = git(root, 'merge-base', default_tip, head).decode().strip()
        commit(baseline, 'initial-push merge base')
        return {'event': kind, 'role': 'INITIAL_FEATURE_BRANCH', 'baseline': baseline, 'target': head,
                'observed_default_tip': default_tip}
    raise ValueError('unsupported/missing CI event for whitespace baseline')


def whitespace_check(root, environment=None):
    environment = os.environ if environment is None else environment
    ci = environment.get('GITHUB_ACTIONS') == 'true'
    def check(*args):
        argv = ['git', '-c', 'core.whitespace=blank-at-eol,blank-at-eof,space-before-tab', *args]
        print('whitespace argv=' + json.dumps(argv), flush=True)
        result = subprocess.run(argv, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
        if result.stdout:
            sys.stdout.buffer.write(result.stdout); sys.stdout.flush()
        # --no-index implies --exit-code: 1 with no --check diagnostics means
        # an ordinary added file, not a whitespace error. Any diagnostic/error
        # remains a failure (whitespace commonly sets the additional exit bit).
        if '--no-index' in args and result.returncode in (0, 1) and not result.stdout:
            return
        result.check_returncode()
        if '--no-index' in args and result.stdout:
            raise ValueError('untracked whitespace check produced diagnostics')
    if ci:
        if git(root, 'status', '--porcelain=v1', '-z'):
            raise ValueError('CI whitespace check requires clean checkout')
        comparison = ci_whitespace_range(root, environment)
        print('whitespace comparison=' + json.dumps(comparison, sort_keys=True), flush=True)
        check('diff', '--check', comparison['baseline'], comparison['target'], '--')
    else:
        # Check both layers: a clean final worktree must not hide a staged error.
        check('diff', '--check', '--cached', 'HEAD', '--')
        check('diff', '--check', '--')
        paths = sorted(p for p in git(root, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0') if p)
        for path in paths:
            check('diff', '--no-index', '--check', '--', '/dev/null', path)
        comparison = {'event': 'LOCAL', 'role': 'LOCAL_INDEX_WORKTREE_UNTRACKED', 'baseline': 'HEAD/index',
                      'target': 'index/worktree', 'untracked_paths': paths}
        print('whitespace comparison=' + json.dumps(comparison, sort_keys=True), flush=True)
    return comparison


def plan(run):
    common = ['xcodebuild', '-project', 'MacSoul.xcodeproj', '-scheme', 'MacSoul',
              '-configuration', 'Debug', '-destination', 'platform=macOS',
              '-derivedDataPath', str(run / 'DerivedData'), 'CODE_SIGNING_ALLOWED=NO']
    return {
        'doctor': ['./scripts/doctor.sh'], 'build': common + ['build'],
        'network': common + ['-resultBundlePath', str(run / 'network.xcresult'),
                             '-only-testing:MacSoulTests/NetworkTests',
                             '-only-testing:MacSoulTests/NetworkPresentationTests', 'test'],
        'unit': common + ['-resultBundlePath', str(run / 'unit.xcresult'), 'test'],
        'script_tests': [sys.executable, 'scripts/test_v011_verification.py'],
        'visual_assets': [sys.executable, 'scripts/verify-visual-assets.py'],
        'current_progress': [sys.executable, 'scripts/verify_v011.py', 'progress'],
        'docs': [sys.executable, 'scripts/verify_v011.py', 'docs'],
        'git_state': [sys.executable, 'scripts/verify_v011.py', 'git-state'],
        'historical_integrity': [sys.executable, 'scripts/verify_v011.py', 'history', '--frozen', str(run / 'historical')],
        'historical_progress': [sys.executable, str(run / 'historical/scripts/test_progress.py')],
    }


def test_summary(root, run, name):
    output = run / (name + '-summary.json')
    result = subprocess.run(['xcrun', 'xcresulttool', 'get', 'test-results', 'summary',
                             '--path', str(run / (name + '.xcresult'))], cwd=root,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    output.write_bytes(result.stdout)
    if result.returncode:
        raise ValueError('xcresult summary unavailable: ' + name)
    data = json.loads(result.stdout)
    return {'tests': data['totalTestCount'], 'failures': data['failedTests'], 'skips': data['skippedTests'],
            'result': data['result'], 'summary': str(output.relative_to(root)),
            'summary_sha256': sha(result.stdout)}


def validate_receipt(root, receipt, expected, run_id, commands):
    if receipt.get('schema') != SCHEMA or receipt.get('run_id') != run_id or receipt.get('identity') != expected:
        raise ValueError('wrong/stale receipt version, run or candidate identity')
    if receipt.get('unexecuted') != UNEXECUTED:
        raise ValueError('automatic receipt cannot grant manual/Live/performance approval')
    historical = {'revision': HISTORICAL, 'tree': HISTORICAL_TREE, 'fingerprint': HISTORICAL_FP,
                  'owner_decision_sha256': HISTORICAL_DECISION}
    if receipt.get('historical_scope') != historical:
        raise ValueError('missing/wrong historical identity')
    if not all(receipt.get('toolchain', {}).get(key) for key in ('xcode', 'macos')):
        raise ValueError('missing current toolchain evidence')
    started = datetime.fromisoformat(receipt['started_at'])
    if expected['checkout_kind'] == 'CI_CLEAN':
        if receipt.get('ci') not in ('RUNNING', 'AUTOMATIC_JOB_CHECKS_PASS') or receipt.get('ci_context', {}).get('GITHUB_SHA') != expected['git_revision']:
            raise ValueError('CI revision/result context mismatch')
    elif receipt.get('ci') != 'NOT_RUN':
        raise ValueError('local receipt cannot claim remote CI')
    run_path = (root / '.artifacts/v0.1.1-runs' / run_id).resolve()
    def check_log(item, name):
        log = root / item['log']
        if not log.resolve().is_relative_to(run_path):
            raise ValueError('log is outside this fresh run: ' + name)
        if not log.is_file() or sha(log.read_bytes()) != item['log_sha256']:
            raise ValueError('missing/changed log: ' + name)
        begin, end = datetime.fromisoformat(item['started_at']), datetime.fromisoformat(item['ended_at'])
        if begin < started or end < begin:
            raise ValueError('stale/invalid command timestamp: ' + name)
    prep = receipt.get('history_preparation')
    prep_argv = [sys.executable, 'scripts/verify_v011.py', 'prepare-history', '--frozen',
                 str(root / '.artifacts/v0.1.1-runs' / run_id / 'historical')]
    if not prep or prep.get('exit_code') != 0 or prep.get('status') != 'PASS' or prep.get('argv') != prep_argv:
        raise ValueError('missing/failed historical preparation evidence')
    check_log(prep, 'history_preparation')
    diagnostic = receipt.get('current_fixed_validator_diagnostic')
    diagnostic_argv = [sys.executable, 'scripts/verify_doc_maintenance.py', 'check']
    if not diagnostic or diagnostic.get('argv') != diagnostic_argv or diagnostic.get('status') != ('PASS' if diagnostic.get('exit_code') == 0 else 'FAIL'):
        raise ValueError('missing original fixed-validator diagnostic')
    check_log(diagnostic, 'current_fixed_validator_diagnostic')
    checks = receipt.get('checks', {})
    if set(checks) != set(REQUIRED):
        raise ValueError('missing/extra required automatic evidence')
    for name in REQUIRED:
        item = checks[name]
        if item['argv'] != commands[name] or item['status'] != ('PASS' if item['exit_code'] == 0 else 'FAIL'):
            raise ValueError('command/result mismatch: ' + name)
        check_log(item, name)
        if item['exit_code'] != 0:
            raise ValueError('required check failed: ' + name)
    for name in ('network', 'unit'):
        counts = checks[name]['counts']
        path = root / counts['summary']
        if not path.resolve().is_relative_to((root / '.artifacts/v0.1.1-runs' / run_id).resolve()):
            raise ValueError('test summary outside current run')
        if sha(path.read_bytes()) != counts['summary_sha256']:
            raise ValueError('missing/changed test summary')
        data = json.loads(path.read_bytes())
        actual = (data['totalTestCount'], data['failedTests'], data['skippedTests'], data['result'])
        if actual != (counts['tests'], counts['failures'], counts['skips'], counts['result']):
            raise ValueError('test summary/count mismatch')
        if any(type(n) is not int or n < 0 for n in actual[:3]) or actual[0] == 0 or actual[1] != 0 or actual[2] != 0 or actual[3] != 'Passed':
            raise ValueError('required tests did not pass')


def run_all(root):
    ci = os.environ.get('GITHUB_ACTIONS') == 'true'
    run_id = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-') + uuid.uuid4().hex[:12]
    run = root / '.artifacts/v0.1.1-runs' / run_id; run.mkdir(parents=True, exist_ok=False)
    receipt = {'schema': SCHEMA, 'run_id': run_id, 'started_at': now(), 'identity': None,
               'checks': {}, 'unexecuted': dict(UNEXECUTED), 'ci': 'RUNNING' if ci else 'NOT_RUN',
               'ci_context': {key: os.environ.get(key, 'NOT_AVAILABLE') for key in
                              ('GITHUB_EVENT_NAME', 'GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_REPOSITORY')},
               'historical_scope': {'revision': HISTORICAL, 'tree': HISTORICAL_TREE, 'fingerprint': HISTORICAL_FP,
                                    'owner_decision_sha256': HISTORICAL_DECISION}, 'status': 'RUNNING'}
    commands = plan(run); problem = None
    try:
        receipt['identity'] = identity(root, ci)
        receipt['current_fixed_validator_diagnostic'] = execute(
            root, [sys.executable, 'scripts/verify_doc_maintenance.py', 'check'],
            run / 'current-fixed-validator.log')
        receipt['current_fixed_validator_diagnostic']['scope'] = (
            'original validator result on current product; outside fixed v0.1.0 acceptance, not a v0.1.1 PASS')
        prep = execute(root, [sys.executable, 'scripts/verify_v011.py', 'prepare-history', '--frozen', str(run / 'historical')],
                       run / 'history-preparation.log', timeout=360)
        receipt['history_preparation'] = prep
        if prep['exit_code']:
            raise ValueError('historical objects/check-out preparation failed; see fresh log')
        for name in REQUIRED:
            assert_unchanged(root, receipt['identity'], ci)
            print('Running ' + name + ' (fresh log)', flush=True)
            item = execute(root, commands[name], run / (name + '.log'))
            receipt['checks'][name] = item
            if name in ('network', 'unit'):
                try:
                    item['counts'] = test_summary(root, run, name)
                except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
                    item['counts_error'] = str(error)
                    raise ValueError('test count evidence unavailable: ' + name) from error
            assert_unchanged(root, receipt['identity'], ci)
            if item['exit_code']:
                raise ValueError('required check failed: ' + name)
        # Tool versions are captured independently in this run, not inferred
        # from prior local logs. Doctor remains the actual project/tool gate.
        receipt['toolchain'] = {key: subprocess.check_output(argv, timeout=60).decode().strip()
                                for key, argv in {'xcode': ['xcodebuild', '-version'],
                                                  'macos': ['sw_vers', '-productVersion']}.items()}
        assert_unchanged(root, receipt['identity'], ci)
        validate_receipt(root, receipt, receipt['identity'], run_id, commands)
        receipt['status'] = 'PASS'
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as error:
        problem = str(error); receipt['status'] = 'FAIL'; receipt['error'] = problem
        # Partial/failed commands remain intact; unexecuted gates are explicit.
        receipt['not_run_checks'] = [name for name in REQUIRED if name not in receipt['checks']]
    receipt['ended_at'] = now()
    if ci:
        receipt['ci'] = 'AUTOMATIC_JOB_CHECKS_PASS' if not problem else 'AUTOMATIC_JOB_CHECKS_FAIL'
    destination = run / 'verification.json'
    destination.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + '\n')
    # Canonical pointer may be replaced; immutable per-run receipts/logs remain.
    latest = root / '.artifacts/v0.1.1-verification.json'
    latest.write_bytes(destination.read_bytes())
    print(receipt['status'] + ': ' + str(destination.relative_to(root)), flush=True)
    if problem:
        print(problem, file=sys.stderr)
    return 1 if problem else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('run', 'progress', 'docs', 'git-state', 'prepare-history', 'history', 'receipt'))
    parser.add_argument('--frozen', type=Path)
    parser.add_argument('--receipt', type=Path)
    args = parser.parse_args()
    try:
        if args.action == 'run':
            return run_all(ROOT)
        if args.action == 'progress':
            current_progress(ROOT)
        elif args.action == 'docs':
            documents(ROOT)
        elif args.action == 'git-state':
            whitespace_check(ROOT)
        elif args.action == 'prepare-history':
            if not args.frozen:
                raise ValueError('explicit fresh historical checkout required')
            historical_checkout(ROOT, args.frozen)
        elif args.action == 'history':
            if not args.frozen or git(args.frozen, 'rev-parse', 'HEAD').decode().strip() != HISTORICAL:
                raise ValueError('missing/wrong fixed historical checkout')
            if identity(args.frozen)['checkout_kind'] != 'LOCAL_CLEAN' or fingerprint(args.frozen) != HISTORICAL_FP:
                raise ValueError('historical checkout not exact/clean')
            historical_integrity(ROOT, args.frozen)
        else:
            receipt = json.loads(args.receipt.read_text())
            run_id = receipt['run_id']; current = identity(ROOT, os.environ.get('GITHUB_ACTIONS') == 'true')
            validate_receipt(ROOT, receipt, current, run_id, plan(ROOT / '.artifacts/v0.1.1-runs' / run_id))
            if receipt['status'] != 'PASS':
                raise ValueError('failed receipt')
            print('PASS: receipt consistency only, NOT authentication or Owner acceptance')
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print('FAIL: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
