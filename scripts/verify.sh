#!/bin/zsh
set -uo pipefail
cd "${0:A:h}/.."
mkdir -p .artifacts

./scripts/doctor.sh > .artifacts/doctor.log 2>&1; doctor_code=$?
./scripts/build.sh; build_code=$?
./scripts/test.sh; test_code=$?
python3 scripts/test_progress.py > .artifacts/progress-tests.log 2>&1; progress_code=$?

# The ledger's committed evidence refers to this local manifest. Write fresh
# command results before checking the ledger, so verification works in a clone.
python3 - "$doctor_code" "$build_code" "$test_code" "$progress_code" <<'PY'
import datetime
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
    ('doctor', 'build', 'unit', 'progress_tests'),
    ('./scripts/doctor.sh', './scripts/build.sh', './scripts/test.sh', 'python3 scripts/test_progress.py'),
    sys.argv[1:],
    ('doctor.log', 'build.log', 'test.log', 'progress-tests.log'),
):
    checks[key] = {
        'command': command,
        'exit_code': int(code),
        'status': 'PASS' if code == '0' else 'FAIL',
        'log': f'.artifacts/{log}',
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
(root / '.artifacts' / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
PY
manifest_code=$?

python3 scripts/verify_progress.py > .artifacts/progress-verify.log 2>&1; ledger_code=$?
python3 - "$ledger_code" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path('.artifacts/verification.json')
if path.is_file():
    result = json.loads(path.read_text())
    code = int(sys.argv[1])
    result['checks']['ledger'] = {
        'command': 'python3 scripts/verify_progress.py',
        'exit_code': code,
        'status': 'PASS' if code == 0 else 'FAIL',
        'log': '.artifacts/progress-verify.log',
    }
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
PY

if (( doctor_code || build_code || test_code || progress_code || manifest_code || ledger_code )); then exit 1; fi
