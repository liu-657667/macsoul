#!/usr/bin/env python3
"""Validate ledger and current evidence; nonzero means status cannot be trusted."""
import hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
VALID={'todo','doing','blocked','verifying','done','deferred'}
def verify(data, root=ROOT, fingerprint=None):
    errors=[]; tasks=data.get('tasks',[])
    ids=[t.get('id') for t in tasks]
    if len(ids)!=len(set(ids)): errors.append('duplicate task ID')
    if sum(t.get('original_points',0) for t in tasks)!=data.get('baseline',{}).get('original_points'): errors.append('baseline points changed')
    source=root/data.get('baseline',{}).get('source','')
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest()!=data.get('baseline',{}).get('sha256'): errors.append('baseline source changed without migration')
    if fingerprint is None: fingerprint=subprocess.check_output([sys.executable,str(root/'scripts/fingerprint.py')],text=True).strip()
    for t in tasks:
        id=t.get('id','?')
        if t.get('status') not in VALID: errors.append(f'{id}: invalid status')
        if t.get('original_points',0)!=t.get('current_points',0) and not t.get('scope_change_approval'): errors.append(f'{id}: unapproved point change')
        for dep in t.get('depends_on',[]):
            if dep not in ids: errors.append(f'{id}: missing dependency {dep}')
        if t.get('status')=='blocked' and not t.get('blocker'): errors.append(f'{id}: blocked without reason')
        if t.get('status')=='deferred' and not t.get('blocker'): errors.append(f'{id}: deferred without reason')
        if t.get('status')=='deferred' and not t.get('scope_change_approval'): errors.append(f'{id}: deferred without approval')
        if t.get('status')=='done':
            accepts={a['id'] for a in t.get('acceptance',[])}
            covered=set()
            for e in t.get('evidence',[]):
                path=root/e.get('path','')
                if not path.is_file(): errors.append(f'{id}: missing evidence file {path}')
                if e.get('fingerprint')!=fingerprint: errors.append(f'{id}: stale fingerprint')
                if e.get('exit_code')!=0 or e.get('status')!='PASS': errors.append(f'{id}: evidence not passing')
                log=root/e.get('log','')
                if not log.is_file(): errors.append(f'{id}: missing evidence log {log}')
                if path.is_file() and path.name=='verification.json':
                    manifest=json.loads(path.read_text())
                    if manifest.get('working_tree_fingerprint')!=fingerprint: errors.append(f'{id}: stale manifest fingerprint')
                    check=manifest.get('checks',{}).get(e.get('check',''),{})
                    if check.get('command')!=e.get('command') or check.get('exit_code')!=0 or check.get('status')!='PASS': errors.append(f'{id}: manifest check mismatch')
                if not e.get('command'): errors.append(f'{id}: evidence missing command')
                if e.get('acceptance_id') in accepts: covered.add(e['acceptance_id'])
            if accepts-covered: errors.append(f'{id}: uncovered acceptance {sorted(accepts-covered)}')
            if any(a['kind']=='manual-ui' for a in t.get('acceptance',[])) and not t.get('human_ui_confirmation'): errors.append(f'{id}: human UI confirmation missing')
    return errors
if __name__=='__main__':
    data=json.loads((ROOT/'tasks.json').read_text())
    errors=verify(data)
    if errors:
        print('\n'.join(errors)); sys.exit(1)
    print(f'PASS: {len(data["tasks"])} tasks; original points {data["baseline"]["original_points"]}')
