#!/usr/bin/env python3
"""One fixed v0.1.0 maintenance candidate; integrity is NOT Owner authorization."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import stat
import tempfile
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
BASELINE = 'b7ca041e0a07623113534e577301f7c3c313df26'
IMPLEMENTATION_BASE = '51f0c0d3a1361ac5ac7ceac52b84175f71ff78e0'
FROM = '1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067'
DECLARATION = 'docs/evidence/v0.1.0-doc-maintenance.json'
OWNER_DECISION = 'docs/evidence/v0.1.0-owner-decision.json'
PAYLOAD = (
    'docs/DESIGN.md', 'docs/SCOPE.md', 'scripts/README.md',
    'scripts/generate_status.py', 'docs/STATUS.md', 'docs/PROGRESS-PROTOCOL.md',
    'scripts/verify_progress.py', 'scripts/test_progress.py', 'scripts/verify.sh',
    'scripts/verify_doc_maintenance.py',
    'MacSoulTests/NetworkTests.swift',
)
CHECKS = {
    'doctor': ('./scripts/doctor.sh', '.artifacts/doctor.log'),
    'build': ('./scripts/build.sh', '.artifacts/build.log'),
    'unit': ('./scripts/test.sh', '.artifacts/test.log'),
    'progress_tests': ('python3 scripts/test_progress.py', '.artifacts/progress-tests.log'),
    'visual_assets': ('python3 scripts/verify-visual-assets.py', '.artifacts/visual-assets-check.json'),
    'doc_maintenance': ('python3 scripts/verify_doc_maintenance.py check', '.artifacts/doc-maintenance.log'),
}
REPORT = 'reports/day-7-release-closeout-2026-10-07.md'
SCOPE_HEADING = '## Owner-authorized System-only layout work unit — automatic checkpoint'
HEADINGS = {
    'D7-02': '### D7-02-A — scoped Owner final Live regression',
    'D7-03': '### D7-03-A — finite performance observation and Owner review',
    'D7-04': '### D7-04-A and D7-06-A — final package privacy and unsigned distribution plan',
    'D7-05': '### D7-05-A — actual version/license/document review',
    'D7-06': '### D7-04-A and D7-06-A — final package privacy and unsigned distribution plan',
    'D7-07': '### D7-07-A — Owner-approved README Mock/Preview screenshots',
    'D7-08': '### D7-08-A — final report, limitations and scoped acceptance',
}


def sha(content):
    return hashlib.sha256(content).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()


def git(root, *args):
    return subprocess.check_output(['git', '--no-replace-objects', '-C', str(root), *args], stderr=subprocess.PIPE)


def blobs(root, entries):
    result = {}
    objects = list(dict.fromkeys(v[1] for v in entries.values()))
    raw = subprocess.check_output(['git', '--no-replace-objects', '-C', str(root), 'cat-file', '--batch'],
                                  input=(''.join(o + '\n' for o in objects)).encode())
    offset = 0
    for oid in objects:
        end = raw.index(b'\n', offset)
        header = raw[offset:end].decode().split()
        if len(header) != 3 or header[:2] != [oid, 'blob']:
            raise ValueError('missing/mismatched blob: ' + oid)
        size = int(header[2]); content = raw[end+1:end+1+size]
        if hashlib.sha1(b'blob ' + str(size).encode() + b'\0' + content).hexdigest() != oid:
            raise ValueError('blob object mismatch: ' + oid)
        result[oid] = content; offset = end + size + 2
    return {p: (mode, result[oid]) for p, (mode, oid) in entries.items()}


def tree_entries(root, revision):
    # Read immutable objects, never export filters/attributes and never network.
    try:
        actual = git(root, 'rev-parse', revision + '^{commit}').decode().strip()
    except subprocess.CalledProcessError as error:
        raise ValueError('missing fixed baseline object: ' + revision) from error
    if actual != revision:
        raise ValueError('baseline object mismatch: ' + revision)
    commit = git(root, 'cat-file', 'commit', revision)
    if hashlib.sha1(b'commit ' + str(len(commit)).encode() + b'\0' + commit).hexdigest() != revision:
        raise ValueError('commit object mismatch')
    entries = {}
    for line in git(root, 'ls-tree', '-r', '-z', '--full-tree', revision).split(b'\0'):
        if not line: continue
        header, path = line.split(b'\t', 1)
        mode, kind, oid = header.decode().split()
        if kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError('Git file type not allowed: ' + path.decode())
        entries[path.decode()] = (mode, oid)
    return blobs(root, entries)


def tree(root, revision):
    return {p: content for p, (_, content) in tree_entries(root, revision).items()}


def regular(root, path):
    file = root / path
    for parent in file.relative_to(root).parents:
        if (root / parent).is_symlink():
            raise ValueError('component symlink ancestor not allowed: ' + path)
    try: mode = file.lstat().st_mode
    except FileNotFoundError: raise ValueError('component deleted: ' + path)
    if not stat.S_ISREG(mode):
        raise ValueError('component symlink/nonregular file not allowed: ' + path)
    return ('100755' if mode & 0o111 else '100644', file.read_bytes())


def current_entries(root, implementation):
    allowed = set(PAYLOAD) | {DECLARATION, OWNER_DECISION}
    head = tree_entries(root, git(root, 'rev-parse', 'HEAD').decode().strip())
    index_objects = {}
    for line in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if not line: continue
        header, path = line.split(b'\t', 1); mode, oid, stage = header.decode().split()
        if stage != '0' or mode not in ('100644', '100755'):
            raise ValueError('index conflict/file type not allowed: ' + path.decode())
        index_objects[path.decode()] = (mode, oid)
    index = blobs(root, index_objects)
    others = {p.decode() for p in git(root, 'ls-files', '--others', '--exclude-standard', '-z').split(b'\0') if p}
    paths = set(implementation) | set(head) | set(index) | others | set(PAYLOAD)
    for folder in ('MacSoul', 'MacSoulTests', 'MacSoul.xcodeproj', 'scripts'):
        for file in (root / folder).rglob('*'):
            path = str(file.relative_to(root))
            if is_input(path) and (file.is_symlink() or not file.is_dir()): paths.add(path)
    for path in (DECLARATION, OWNER_DECISION):
        if (root/path).exists() or (root/path).is_symlink(): paths.add(path)
    current = {p: regular(root, p) for p in sorted(paths)}
    for path in paths:
        original = implementation.get(path)
        if path not in allowed:
            if original is None: raise ValueError('outside payload file added: ' + path)
            if current[path] != original or head.get(path) != original or index.get(path) != original:
                raise ValueError('outside payload content/mode/deletion changed: ' + path)
        else:
            # Permit unstaged base + patch, or exact candidate staged/committed.
            for label, entries in (('HEAD', head), ('index', index)):
                entry = entries.get(path)
                same_decision_binding = False
                if path == OWNER_DECISION and entry is not None and entry[0] == current[path][0]:
                    prior = json.loads(entry[1]); now = json.loads(current[path][1])
                    same_decision_binding = ({k:v for k,v in prior.items() if k not in ('decision','review_reference')}
                                             == {k:v for k,v in now.items() if k not in ('decision','review_reference')}
                                             and prior.get('decision') in ('PENDING','ACCEPTED'))
                if entry not in (original, current[path]) and not same_decision_binding:
                    raise ValueError(label + '/worktree candidate divergence: ' + path)
            if path in (DECLARATION, OWNER_DECISION) and current[path][0] != '100644':
                raise ValueError('record mode must be 100644: ' + path)
    return current


def is_input(path):
    p = Path(path)
    return ((p.parts[0] in ('MacSoul', 'MacSoulTests', 'MacSoul.xcodeproj', 'scripts')
             and 'xcuserdata' not in p.parts and '__pycache__' not in p.parts and p.suffix != '.pyc')
            or path in ('docs/DESIGN.md', 'docs/SCOPE.md'))


def digest(files):
    h = hashlib.sha256()
    for path in sorted((p for p in files if is_input(p)), key=Path):
        h.update(path.encode() + b'\0' + files[path] + b'\0')
    return h.hexdigest()


def section(content, heading):
    text = content.decode()
    start = text.index(heading + '\n')
    end = re.search(r'^#{1,3} ', text[start + len(heading) + 1:], re.M)
    return text[start:start + len(heading) + 1 + end.start() if end else len(text)].encode()


def describe(root, data=None):
    historical = tree(root, BASELINE)
    implementation = tree(root, IMPLEMENTATION_BASE)
    if digest(historical) != FROM or digest(implementation) != FROM:
        raise ValueError('baseline fingerprint mismatch')
    implementation_entries = tree_entries(root, IMPLEMENTATION_BASE)
    modes = {p: entry[0] for p, entry in implementation_entries.items()}
    entries = current_entries(root, implementation_entries)
    current = {p: content for p, (_, content) in entries.items()}
    old_inputs = {p: sha(v) for p, v in historical.items() if is_input(p)}
    new_inputs = {p: sha(v) for p, v in current.items() if is_input(p)}
    components = [{'path': p, 'before': old_inputs.get(p), 'after': new_inputs.get(p)}
                  for p in sorted(old_inputs.keys() | new_inputs.keys())]
    changed = [v for v in components if v['before'] != v['after']]
    if any(v['path'] not in PAYLOAD for v in changed):
        raise ValueError('fingerprint component changed outside payload')
    if any(historical[p] != current[p] for p in historical
           if p.startswith(('MacSoul/', 'MacSoulTests/', 'MacSoul.xcodeproj/'))
           and p != 'MacSoulTests/NetworkTests.swift'):
        raise ValueError('accepted product/other-test/project content changed')
    baseline_data = json.loads(historical['tasks.json'])
    if current['tasks.json'] != historical['tasks.json'] or (data is not None and data != baseline_data):
        raise ValueError('original task/evidence/human flags changed')
    payload = [{'path': p, 'before_sha256': sha(implementation[p]) if p in implementation else None,
                'after_sha256': sha(current[p]), 'before_mode': modes.get(p),
                'after_mode': entries[p][0]} for p in sorted(PAYLOAD)]
    mappings = []
    for task in baseline_data['tasks']:
        if task['status'] != 'done':
            continue
        for index, evidence in enumerate(task['evidence']):
            if evidence['fingerprint'] != FROM or evidence['status'] != 'PASS' or evidence['exit_code'] != 0:
                raise ValueError('original evidence outside fixed passing baseline')
            entry = {'task': task['id'], 'acceptance': evidence['acceptance_id'], 'index': index,
                     'original_entry_sha256': sha(canonical(evidence)), 'original_evidence': evidence}
            if evidence['path'] == '.artifacts/verification.json':
                key = evidence['check']
                if key not in CHECKS or (evidence['command'], evidence['log']) != CHECKS[key]:
                    raise ValueError('automatic evidence command mapping mismatch')
                entry.update(kind='fresh_automatic', check=key)
            else:
                if evidence['path'] != REPORT or evidence['log'] != REPORT:
                    raise ValueError('unmapped historical evidence')
                scope = evidence.get('check') == 'day7_system_layout_scope_review'
                heading = SCOPE_HEADING if scope else HEADINGS[task['id']]
                body = section(historical[REPORT], heading)
                if body not in current[REPORT]:
                    raise ValueError('historical report section changed: ' + heading)
                entry.update(kind='historical_scope' if scope else 'historical_day7', report=REPORT,
                             heading=heading, section_sha256=sha(body), source_revision=BASELINE,
                             attribution='original observation/review only; not rerun')
            mappings.append(entry)
    counts = collections.Counter(e['kind'] for e in mappings)
    if counts != {'fresh_automatic': 48, 'historical_scope': 15, 'historical_day7': 7}:
        raise ValueError('fixed evidence inventory mismatch')
    return {
        'schema': 'macsoul-v0.1.0-fixed-maintenance-1',
        'historical_baseline': BASELINE, 'implementation_base': IMPLEMENTATION_BASE,
        'from_fingerprint': FROM, 'to_fingerprint': digest(current),
        'payload_encoding': 'canonical UTF-8 sorted JSON path/before/after SHA256 and Git mode records; declaration excluded',
        'payload': payload, 'payload_sha256': sha(canonical(payload)),
        'declaration_path': DECLARATION,
        'owner_decision_path': OWNER_DECISION,
        'allowlist': sorted(set(PAYLOAD) | {DECLARATION, OWNER_DECISION}),
        'decision_policy': 'Exact fixed record, independently hashed; PENDING refuses coverage. JSON binds identity, not human authentication.',
        'authorization_rule': 'Coverage requires the separate exact Owner decision; this declaration does not grant authorization.',
        'tasks_sha256': sha(historical['tasks.json']),
        'components': components, 'evidence_mappings': mappings,
        'documents': 'Fresh document checks coexist with historical D7-05 RC review; no new human acceptance.',
    }


def integrity(root, data=None):
    expected = describe(root, data)
    raw = regular(root, DECLARATION)[1]
    if json.loads(raw) != expected:
        raise ValueError('declaration/payload/fingerprint/mapping mismatch')
    if decision_identity(root) is not None:
        record = json.loads(regular(root, OWNER_DECISION)[1])
        required = {'historical_baseline': BASELINE, 'implementation_base': IMPLEMENTATION_BASE,
                    'from_fingerprint': FROM, 'to_fingerprint': expected['to_fingerprint'],
                    'payload_sha256': expected['payload_sha256'], 'declaration_sha256': sha(raw)}
        if not isinstance(record, dict) or set(record) != set(required) | {'decision', 'review_reference'} or any(record[k] != v for k,v in required.items()):
            raise ValueError('Owner decision record identity/schema mismatch')
        if record['decision'] not in ('PENDING', 'ACCEPTED') or (record['decision'] == 'PENDING' and record['review_reference'] is not None) or (record['decision'] == 'ACCEPTED' and (not isinstance(record['review_reference'], str) or not record['review_reference'].strip())):
            raise ValueError('Owner decision record state/reference invalid')
    return expected, sha(raw)


def decision_identity(root):
    path = root / OWNER_DECISION
    if not path.exists() and not path.is_symlink(): return None
    mode, raw = regular(root, OWNER_DECISION)
    if mode != '100644': raise ValueError('decision record mode must be 100644')
    value = json.loads(raw)
    if not isinstance(value, dict): raise ValueError('Owner decision record must be an object')
    return {'path': OWNER_DECISION, 'sha256': sha(raw), 'decision': value.get('decision')}


def load_owner_decision(root, path=None):
    selected = root / OWNER_DECISION
    if path is not None and Path(path).absolute() != selected.absolute():
        raise ValueError('Owner decision must use fixed reviewable path: ' + OWNER_DECISION)
    identity = decision_identity(root)
    if identity is None:
        if path is not None: raise ValueError('explicit Owner decision record missing')
        return None, None
    value = json.loads(regular(root, OWNER_DECISION)[1])
    if not isinstance(value, dict): raise ValueError('Owner decision record must be an object')
    if str(value.get('review_reference', '')).startswith('TEST_FIXTURE_ONLY'):
        raise ValueError('test fixture is not a production Owner decision')
    return value, identity


def fresh_results(root, declaration, declaration_sha):
    manifest = json.loads((root / '.artifacts/verification.json').read_text())
    identity = {'implementation_base': IMPLEMENTATION_BASE, 'payload_sha256': declaration['payload_sha256'],
                'declaration_sha256': declaration_sha}
    if (manifest.get('git_revision') != git(root, 'rev-parse', 'HEAD').decode().strip()
            or manifest.get('working_tree_fingerprint') != declaration['to_fingerprint']
            or manifest.get('candidate_identity') != identity or not manifest.get('checked_at')
            or manifest.get('owner_decision_input') != decision_identity(root)):
        raise ValueError('fresh manifest revision/fingerprint/payload/declaration mismatch')
    for key, (command, log) in CHECKS.items():
        check = manifest.get('checks', {}).get(key, {})
        if (check.get('command'), check.get('log'), check.get('exit_code'), check.get('status')) != (command, log, 0, 'PASS'):
            raise ValueError('fresh manifest missing/failing/mismatched check: ' + key)
        file = root / log
        if not file.is_file() or check.get('log_sha256') != sha(file.read_bytes()):
            raise ValueError('fresh manifest log mismatch: ' + key)
    if any(manifest.get(k) != 'NOT_RUN' for k in ('manual_ui', 'performance', 'live_provider')):
        raise ValueError('fresh automatic manifest must not claim human/live/performance runs')
    # Deliberately no checks.ledger dependency: ledger runs after this manifest.
    return manifest


def coverage(root, data, fingerprint, owner_decision=None):
    """An externally reviewed decision is explicit input, never a generated approval.

    JSON integrity cannot authenticate a human. Supplying this input is a governance
    action reserved for the Owner/reviewer; production CLI reads only the fixed decision record; absence means PENDING_FINAL_OWNER_DECISION.
    """
    declaration, declaration_sha = integrity(root, data)
    if fingerprint != declaration['to_fingerprint']:
        raise ValueError('target fingerprint mismatch')
    fresh_results(root, declaration, declaration_sha)
    required = {'decision': 'ACCEPTED', 'historical_baseline': BASELINE,
                'implementation_base': IMPLEMENTATION_BASE, 'from_fingerprint': FROM,
                'to_fingerprint': fingerprint, 'payload_sha256': declaration['payload_sha256'],
                'declaration_sha256': declaration_sha}
    if owner_decision is not None and not isinstance(owner_decision, dict):
        raise ValueError('Owner decision must be an object')
    if owner_decision is None or owner_decision.get('decision') == 'PENDING' and not owner_decision.get('review_reference'):
        raise ValueError('PENDING_FINAL_OWNER_DECISION: production exception refused')
    if any(owner_decision.get(k) != v for k, v in required.items()) or not isinstance(owner_decision.get('review_reference'), str) or not owner_decision['review_reference'].strip():
        raise ValueError('exact Owner decision missing/mismatched; exception refused')
    return {(e['task'], e['index']): e for e in declaration['evidence_mappings']}


def anchors(text):
    found = set(); counts = collections.Counter()
    for line in text.splitlines():
        if re.match(r'^#{1,6} ', line):
            value = re.sub(r'\[([^]]+)\]\([^)]*\)', r'\1', line.lstrip('# ').strip()).lower()
            value = re.sub(r'[^\w\-\s]', '', value).replace(' ', '-')
            n = counts[value]; counts[value] += 1
            found.add(value + (f'-{n}' if n else ''))
    return found


def document_checks(root):
    # STATUS equality is checked in isolation, without overwriting candidate output.
    with tempfile.TemporaryDirectory(prefix='macsoul-generator-') as directory:
        copy = Path(directory); (copy / 'scripts').mkdir(); (copy / 'docs').mkdir()
        (copy / 'scripts/generate_status.py').write_bytes((root / 'scripts/generate_status.py').read_bytes())
        (copy / 'tasks.json').write_bytes((root / 'tasks.json').read_bytes())
        subprocess.run([sys.executable, str(copy / 'scripts/generate_status.py')], check=True)
        actual = (root / 'docs/STATUS.md').read_bytes()
        if (copy / 'docs/STATUS.md').read_bytes() != actual:
            raise ValueError('generator/STATUS mismatch')
        subprocess.run([sys.executable, str(copy / 'scripts/generate_status.py')], check=True)
        if (copy / 'docs/STATUS.md').read_bytes() != actual:
            raise ValueError('generator is not deterministic')
    count = fragments = 0
    for path in (p for p in PAYLOAD if p.endswith('.md')):
        text = re.sub(r'```[\s\S]*?```', '', (root / path).read_text())
        for raw in re.findall(r'!?\[[^]\n]*\]\(([^)]+)\)', text):
            link = urlsplit(raw.strip().strip('<>'))
            if link.scheme or raw.startswith('//'):
                continue
            count += 1
            target = (root / path).parent / unquote(link.path) if link.path else root / path
            if not target.is_file():
                raise ValueError('missing document link: ' + path + ': ' + raw)
            if link.fragment:
                fragments += 1
                if unquote(link.fragment) not in anchors(target.read_text()):
                    raise ValueError('missing document fragment: ' + path + ': ' + raw)
    text = (root / 'docs/STATUS.md').read_text()
    if not ('48/48 done；已闭合' in text and '51 done，8 verifying' in text
            and 'Day 7 原始任务已按账本关闭' in text and '截图/GIF PENDING' not in text):
        raise ValueError('current STATUS inconsistent with fixed ledger')
    return {'local_links': count, 'fragments': fragments, 'generator': 'PASS', 'current_status': 'PASS'}


def prepare(root):
    for revision in (BASELINE, IMPLEMENTATION_BASE):
        try:
            actual = git(root, 'rev-parse', revision + '^{commit}').decode().strip()
        except subprocess.CalledProcessError:
            print('Explicit public fixed-object fetch: ' + revision, flush=True)
            subprocess.run(['git', '-C', str(root), 'fetch', '--no-tags',
                            'https://github.com/liu-657667/macsoul.git', revision], check=True)
            actual = git(root, 'rev-parse', revision + '^{commit}').decode().strip()
        if actual != revision:
            raise ValueError('prepared object mismatch')
        print('Prepared exact commit: ' + actual)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('prepare', 'describe', 'check'))
    args = parser.parse_args()
    try:
        if args.action == 'prepare':
            prepare(ROOT)
        elif args.action == 'describe':
            print(json.dumps(describe(ROOT), ensure_ascii=False, indent=2))
        else:
            declaration, declaration_sha = integrity(ROOT)
            result = document_checks(ROOT)
            result.update(status='PASS', scope='integrity/docs only; decision record is separate, not human authentication',
                          fingerprint=declaration['to_fingerprint'], payload_sha256=declaration['payload_sha256'],
                          declaration_sha256=declaration_sha,
                          changed_components=sum(c['before'] != c['after'] for c in declaration['components']),
                          unchanged_components=sum(c['before'] == c['after'] for c in declaration['components']),
                          fresh_automatic_references=48, historical_scope_references=15, historical_day7_references=7)
            print(json.dumps(result, indent=2))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print('FAIL: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
