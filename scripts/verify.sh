#!/bin/zsh
set -uo pipefail
cd "${0:A:h}/.."
mkdir -p .artifacts
./scripts/doctor.sh > .artifacts/doctor.log 2>&1; doctor_code=$?
./scripts/build.sh; build_code=$?
rm -rf .artifacts/MacSoulTests.xcresult
./scripts/test.sh; test_code=$?
python3 scripts/test_progress.py > .artifacts/progress-tests.log 2>&1; progress_code=$?
python3 scripts/verify_progress.py > .artifacts/progress-verify.log 2>&1; ledger_code=$?
python3 - "$doctor_code" "$build_code" "$test_code" "$progress_code" "$ledger_code" <<'PY'
import json,subprocess,sys,datetime,pathlib,platform
root=pathlib.Path.cwd()
try: revision=subprocess.check_output(['git','rev-parse','HEAD'],stderr=subprocess.DEVNULL,text=True).strip()
except Exception: revision=None
fingerprint=subprocess.check_output([sys.executable,'scripts/fingerprint.py'],text=True).strip()
keys=['doctor','build','unit','progress_tests','ledger']
result={'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(), 'git_revision':revision, 'working_tree_fingerprint':fingerprint,
        'toolchain':{'macos':platform.mac_ver()[0], 'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip()},
        'checks':{k:{'command':c,'exit_code':int(v),'status':'PASS' if v=='0' else 'FAIL','log':f'.artifacts/{l}'} for k,c,v,l in zip(keys,
        ['./scripts/doctor.sh','./scripts/build.sh','./scripts/test.sh','python3 scripts/test_progress.py','python3 scripts/verify_progress.py'],sys.argv[1:],
        ['doctor.log','build.log','test.log','progress-tests.log','progress-verify.log'])},
        'manual_ui':'NOT_RUN','performance':'NOT_RUN','live_provider':'NOT_RUN'}
(root/'.artifacts'/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
PY
if (( doctor_code || build_code || test_code || progress_code || ledger_code )); then exit 1; fi
