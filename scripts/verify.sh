#!/bin/zsh
set -uo pipefail
cd "${0:A:h}/.."
mkdir -p .artifacts
# Never append a new result to a stale manifest after a failed receipt build.
rm -f .artifacts/verification.json

ledger_command=(python3 scripts/verify_progress.py)
decision_path=docs/evidence/v0.1.0-owner-decision.json
if (( $# )); then
  if [[ $# != 2 || "$1" != --owner-decision || "$2" != "$decision_path" ]]; then
    print -u2 'Usage: ./scripts/verify.sh [--owner-decision docs/evidence/v0.1.0-owner-decision.json]'
    exit 2
  fi
  ledger_command+=(--owner-decision "$decision_path")
elif [[ -e "$decision_path" || -L "$decision_path" ]]; then
  ledger_command+=(--owner-decision "$decision_path")
fi

# Only the fixed maintenance candidate needs explicit public baseline preparation.
# The validator itself never fetches. Default verification remains unchanged.
maintenance_code=0
prepare_code=0
if [[ -f docs/evidence/v0.1.0-doc-maintenance.json ]]; then
  python3 scripts/verify_doc_maintenance.py prepare > .artifacts/baseline-prepare.log 2>&1
  prepare_code=$?
  python3 scripts/verify_doc_maintenance.py check > .artifacts/doc-maintenance.log 2>&1
  maintenance_code=$?
fi

./scripts/doctor.sh > .artifacts/doctor.log 2>&1; doctor_code=$?
./scripts/build.sh; build_code=$?
./scripts/test.sh; test_code=$?
python3 scripts/test_progress.py > .artifacts/progress-tests.log 2>&1; progress_code=$?
python3 scripts/verify-visual-assets.py > .artifacts/visual-assets-check.json 2>&1; visual_assets_code=$?

# The ledger's committed evidence refers to this local manifest. Write fresh
# command results before checking the ledger, so verification works in a clone.
python3 - "$doctor_code" "$build_code" "$test_code" "$progress_code" "$visual_assets_code" "$maintenance_code" "$prepare_code" <<'PY'
import datetime
import hashlib
import json
import pathlib
import platform
import subprocess
import sys

root = pathlib.Path.cwd()

def output(args):
    try:
        return subprocess.check_output(args, stderr=subprocess.DEVNULL, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return None

fingerprint = output([sys.executable, 'scripts/fingerprint.py'])
checks = {}
for key, command, code, log in zip(
    ('doctor', 'build', 'unit', 'progress_tests', 'visual_assets', 'doc_maintenance'),
    ('./scripts/doctor.sh', './scripts/build.sh', './scripts/test.sh', 'python3 scripts/test_progress.py', 'python3 scripts/verify-visual-assets.py', 'python3 scripts/verify_doc_maintenance.py check'),
    sys.argv[1:7],
    ('doctor.log', 'build.log', 'test.log', 'progress-tests.log', 'visual-assets-check.json', 'doc-maintenance.log'),
):
    if key == 'doc_maintenance' and not (root/'docs/evidence/v0.1.0-doc-maintenance.json').is_file():
        continue
    checks[key] = {
        'command': command,
        'exit_code': int(code),
        'status': 'PASS' if code == '0' else 'FAIL',
        'log': f'.artifacts/{log}',
        'log_sha256': hashlib.sha256((root/'.artifacts'/log).read_bytes()).hexdigest() if (root/'.artifacts'/log).is_file() else None,
    }

result = {
    'checked_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'git_revision': output(['git', 'rev-parse', 'HEAD']),
    'working_tree_fingerprint': fingerprint,
    'toolchain': {'macos': platform.mac_ver()[0], 'xcode': output(['xcodebuild', '-version'])},
    'checks': checks,
    'manual_ui': 'NOT_RUN',
    'performance': 'NOT_RUN',
    'live_provider': 'NOT_RUN',
}
declaration_path = root/'docs/evidence/v0.1.0-doc-maintenance.json'
if declaration_path.is_file():
    prepare_log = root/'.artifacts/baseline-prepare.log'
    checks['baseline_prepare'] = {
        'command': 'python3 scripts/verify_doc_maintenance.py prepare',
        'argv': ['python3', 'scripts/verify_doc_maintenance.py', 'prepare'],
        'exit_code': int(sys.argv[7]), 'status': 'PASS' if sys.argv[7] == '0' else 'FAIL',
        'log': '.artifacts/baseline-prepare.log',
        'log_sha256': hashlib.sha256(prepare_log.read_bytes()).hexdigest() if prepare_log.is_file() else None,
    }
    declaration = json.loads(declaration_path.read_text())
    result['candidate_identity'] = {
        'implementation_base': declaration['implementation_base'],
        'payload_sha256': declaration['payload_sha256'],
        'declaration_sha256': hashlib.sha256(declaration_path.read_bytes()).hexdigest(),
    }
if declaration_path.is_file():
    sys.path.insert(0, str(root/'scripts'))
    from verify_doc_maintenance import decision_identity
    result['owner_decision_input'] = decision_identity(root)
(root / '.artifacts' / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
PY
manifest_code=$?

"${ledger_command[@]}" > .artifacts/progress-verify.log 2>&1; ledger_code=$?
python3 - "$ledger_code" "${ledger_command[@]}" <<'PY'
import json
import pathlib
import sys
import shlex
import hashlib

path = pathlib.Path('.artifacts/verification.json')
if not path.is_file():
    print('FAIL: current verification manifest unavailable', file=sys.stderr)
    sys.exit(1)
if path.is_file():
    result = json.loads(path.read_text())
    code = int(sys.argv[1])
    result['checks']['ledger'] = {
        'command': shlex.join(sys.argv[2:]),
        'argv': sys.argv[2:],
        'owner_decision_input': result.get('owner_decision_input'),
        'exit_code': code,
        'status': 'PASS' if code == 0 else 'FAIL',
        'log': '.artifacts/progress-verify.log',
        'log_sha256': hashlib.sha256(pathlib.Path('.artifacts/progress-verify.log').read_bytes()).hexdigest(),
    }
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
PY
receipt_code=$?

if (( prepare_code || receipt_code || doctor_code || build_code || test_code || progress_code || visual_assets_code || manifest_code || maintenance_code || ledger_code )); then exit 1; fi
