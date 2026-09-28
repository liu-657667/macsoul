#!/usr/bin/env python3
import copy,json,subprocess,sys
from pathlib import Path
from verify_progress import verify,ROOT
base=json.loads((ROOT/'tasks.json').read_text())
for task in base['tasks']:
    if task['status']=='done':
        task['status']='verifying'; task['evidence']=[]
fingerprint=subprocess.check_output([sys.executable,str(ROOT/'scripts/fingerprint.py')],text=True).strip()
assert not verify(base,fingerprint=fingerprint)
def bad(mutator, expected):
    obj=copy.deepcopy(base); mutator(obj)
    errors=verify(obj,fingerprint=fingerprint)
    assert any(expected in e for e in errors), errors
bad(lambda o:o['tasks'].append(copy.deepcopy(o['tasks'][0])),'duplicate task ID')
bad(lambda o:o['tasks'][0].update(status='blocked',blocker=None),'blocked without reason')
bad(lambda o:next(t for t in o['tasks'] if t['id']=='A1').update(status='done'),'uncovered acceptance')
bad(lambda o:o['tasks'][0].update(current_points=2),'unapproved point change')
bad(lambda o:o['tasks'][0].update(depends_on=['MISSING']),'missing dependency')
bad(lambda o:o['tasks'][0].update(status='deferred',blocker='delayed'),'deferred without approval')
print('PASS: positive ledger and six negative cases')
