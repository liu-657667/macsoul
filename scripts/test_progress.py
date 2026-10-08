#!/usr/bin/env python3
import copy,json,subprocess,sys,tempfile
from pathlib import Path
from verify_progress import verify,ROOT
base=json.loads((ROOT/'tasks.json').read_text())
for task in base['tasks']:
    if task['status']=='done':
        task['status']='verifying'; task['evidence']=[]
fingerprint=subprocess.check_output([sys.executable,str(ROOT/'scripts/fingerprint.py')],text=True).strip()
# The original six structural cases intentionally have no done evidence. Isolate
# their baseline file so they cannot activate the new real maintenance candidate.
structure=tempfile.TemporaryDirectory(prefix='macsoul-structure-fixture-')
structure_root=Path(structure.name);(structure_root/'docs').mkdir()
(structure_root/'docs/7-DAY-PLAN.md').write_bytes((ROOT/'docs/7-DAY-PLAN.md').read_bytes())
assert not verify(base,root=structure_root,fingerprint=fingerprint)
def bad(mutator, expected):
    obj=copy.deepcopy(base); mutator(obj)
    errors=verify(obj,root=structure_root,fingerprint=fingerprint)
    assert any(expected in e for e in errors), errors
bad(lambda o:o['tasks'].append(copy.deepcopy(o['tasks'][0])),'duplicate task ID')
bad(lambda o:o['tasks'][0].update(status='blocked',blocker=None),'blocked without reason')
bad(lambda o:next(t for t in o['tasks'] if t['id']=='A1').update(status='done',evidence=[]),'uncovered acceptance')
bad(lambda o:o['tasks'][0].update(current_points=2),'unapproved point change')
bad(lambda o:o['tasks'][0].update(depends_on=['MISSING']),'missing dependency')
bad(lambda o:o['tasks'][0].update(status='deferred',blocker='delayed'),'deferred without approval')
print('PASS: positive structure fixture and six original negative cases')
structure.cleanup()

# Full done-evidence fixtures, isolated from real evidence and Owner decisions.
# These simulate command outcomes; only verify.sh produces real execution evidence.
import hashlib
import shutil
import tempfile
from verify_doc_maintenance import (BASELINE, IMPLEMENTATION_BASE, FROM, DECLARATION,
                                   PAYLOAD, CHECKS, OWNER_DECISION, decision_identity, canonical, describe, sha, tree_entries)

def initial_fixture(source, fixture):
    # Transport only from the explicitly prepared LOCAL source. Never depend on
    # advertised branches, main, alternates, network or a caller's object cache.
    subprocess.run(['git', 'clone', '--quiet', '--no-local', '--no-checkout',
                    str(source), str(fixture)], check=True)
    subprocess.run(['git', '-C', str(fixture), 'fetch', '--quiet', '--update-shallow',
                    '--no-tags', str(source), BASELINE, IMPLEMENTATION_BASE], check=True)
    for revision in (BASELINE, IMPLEMENTATION_BASE):
        tree_entries(fixture, revision)  # Exact commit/tree/blob identities required.
    assert not (fixture/'.git/objects/info/alternates').exists()
    subprocess.run(['git', '-C', str(fixture), 'checkout', '--quiet', '--detach',
                    IMPLEMENTATION_BASE], check=True)


with tempfile.TemporaryDirectory(prefix='macsoul-progress-fixture-') as directory:
    fixture = Path(directory)/'repo'
    initial_fixture(ROOT, fixture)
    artifact = fixture/'.artifacts'; artifact.mkdir()
    real_done = json.loads((fixture/'tasks.json').read_text())
    assert sum(t['status']=='done' for t in real_done['tasks']) == 51
    assert sum(len(t.get('evidence',[])) for t in real_done['tasks'] if t['status']=='done') == 70

    def write_manifest(fp, declaration=None):
        checks={}
        for key,(command,log) in CHECKS.items():
            file=fixture/log
            file.write_text('TEST FIXTURE ONLY: simulated '+key+' result; not real execution.\n')
            checks[key]={'command':command,'log':log,'log_sha256':sha(file.read_bytes()),'exit_code':0,'status':'PASS'}
        value={'git_revision':IMPLEMENTATION_BASE,'working_tree_fingerprint':fp,
               'checked_at':'TEST_FIXTURE_ONLY','checks':checks,
               'manual_ui':'NOT_RUN','performance':'NOT_RUN','live_provider':'NOT_RUN'}
        if declaration:
            value['candidate_identity']={'implementation_base':IMPLEMENTATION_BASE,
                                         'payload_sha256':declaration['payload_sha256'],
                                         'declaration_sha256':sha((fixture/DECLARATION).read_bytes())}
            value['owner_decision_input'] = decision_identity(fixture)
        (artifact/'verification.json').write_text(json.dumps(value))
        return value

    write_manifest(FROM)
    assert not verify(real_done,root=fixture), 'strict matching done path must pass at actual baseline'
    checks_run=['strict real 51-done/70-evidence matching baseline']
    for path in PAYLOAD:
        (fixture/path).parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/path,fixture/path)
    declaration=describe(fixture)
    (fixture/DECLARATION).parent.mkdir(parents=True,exist_ok=True)
    (fixture/DECLARATION).write_text(json.dumps(declaration,ensure_ascii=False,indent=2)+'\n')
    target=declaration['to_fingerprint']; manifest=write_manifest(target,declaration)
    decision={'decision':'ACCEPTED','historical_baseline':BASELINE,'implementation_base':IMPLEMENTATION_BASE,
              'from_fingerprint':FROM,'to_fingerprint':target,'payload_sha256':declaration['payload_sha256'],
              'declaration_sha256':sha((fixture/DECLARATION).read_bytes()),
              'review_reference':'TEST_FIXTURE_ONLY: no real Owner approval'}
    assert not verify(real_done,root=fixture,owner_decision=decision), 'exact mapped done fixture'
    checks_run.append('exact 48 fresh / 22 historical done mappings; TEST FIXTURE ONLY approval')
    assert any('PENDING_FINAL_OWNER_DECISION' in e for e in verify(real_done,root=fixture))
    checks_run.append('production exception rejected without final decision')

    saved={path:(fixture/path).read_bytes() for path in set(PAYLOAD)|{DECLARATION,'tasks.json',
           'MacSoul/Models/MacSoulModels.swift', 'reports/day-7-release-closeout-2026-10-07.md'}}
    def reset():
        for path,content in saved.items():
            (fixture/path).parent.mkdir(parents=True,exist_ok=True)
            (fixture/path).write_bytes(content)
        (artifact/'verification.json').write_text(json.dumps(manifest))
    def negative(name,mutate,expected=None):
        reset(); obj=copy.deepcopy(real_done); approval=copy.deepcopy(decision)
        mutate(obj,approval)
        errors=verify(obj,root=fixture,owner_decision=approval)
        assert errors and (not expected or any(expected in e for e in errors)), (name,errors)
        checks_run.append(name)
    def decl_change(key,value):
        obj=copy.deepcopy(declaration);obj[key]=value
        (fixture/DECLARATION).write_text(json.dumps(obj))
    def manifest_change(mutator):
        obj=copy.deepcopy(manifest);mutator(obj);(artifact/'verification.json').write_text(json.dumps(obj))

    negative('wrong declaration source',lambda o,a:decl_change('from_fingerprint','0'*64),'declaration')
    negative('wrong declaration target',lambda o,a:decl_change('to_fingerprint','0'*64),'declaration')
    negative('wrong payload digest',lambda o,a:decl_change('payload_sha256','0'*64),'declaration')
    negative('changed declaration bytes without new decision',lambda o,a:(fixture/DECLARATION).write_text(json.dumps(declaration)), 'fresh manifest')
    negative('wrong Owner from',lambda o,a:a.update(from_fingerprint='0'*64),'Owner decision')
    negative('wrong Owner to',lambda o,a:a.update(to_fingerprint='0'*64),'Owner decision')
    negative('wrong Owner payload',lambda o,a:a.update(payload_sha256='0'*64),'Owner decision')
    negative('wrong Owner declaration',lambda o,a:a.update(declaration_sha256='0'*64),'Owner decision')
    negative('Owner not accepted',lambda o,a:a.update(decision='PENDING'),'Owner decision')
    negative('component deleted',lambda o,a:(fixture/'MacSoul/Models/MacSoulModels.swift').unlink(),'deleted')
    negative('component content changed',lambda o,a:(fixture/'MacSoul/Models/MacSoulModels.swift').write_text('TEST altered'), 'outside payload')
    added=fixture/'scripts/fixture-added.py'
    negative('component added',lambda o,a:added.write_text('# TEST added\n'),'outside payload')
    added.unlink()
    negative('payload content changed',lambda o,a:(fixture/'scripts/README.md').write_text('TEST changed\n'),'declaration')
    negative('task status changed',lambda o,a:o['tasks'][0].update(status='verifying'),'task/evidence/human')
    negative('original evidence modified',lambda o,a:next(t for t in o['tasks'] if t['status']=='done')['evidence'][0].update(status='FAIL'),'task/evidence/human')
    negative('human flag changed',lambda o,a:next(t for t in o['tasks'] if t.get('human_ui_confirmation')).update(human_ui_confirmation=False),'task/evidence/human')
    negative('raw task bytes changed',lambda o,a:(fixture/'tasks.json').write_bytes(saved['tasks.json']+b'\n'),'outside payload')
    negative('mapping outside task/new criterion reuse',lambda o,a:o['tasks'].append(dict(copy.deepcopy(next(t for t in o['tasks'] if t['status']=='done')),id='NEW')), 'task/evidence/human')
    negative('mapping missing',lambda o,a:decl_change('evidence_mappings',declaration['evidence_mappings'][:-1]),'declaration')
    negative('historical report changed',lambda o,a:(fixture/'reports/day-7-release-closeout-2026-10-07.md').write_text('TEST changed\n'),'outside payload')
    negative('fresh manifest missing check',lambda o,a:manifest_change(lambda m:m['checks'].pop('unit')),'check: unit')
    negative('fresh manifest wrong command',lambda o,a:manifest_change(lambda m:m['checks']['unit'].update(command='true')),'check: unit')
    negative('fresh manifest failed result',lambda o,a:manifest_change(lambda m:m['checks']['unit'].update(exit_code=1,status='FAIL')),'check: unit')
    negative('fresh manifest wrong fingerprint',lambda o,a:manifest_change(lambda m:m.update(working_tree_fingerprint=FROM)), 'fresh manifest')
    negative('fresh manifest wrong revision',lambda o,a:manifest_change(lambda m:m.update(git_revision=BASELINE)),'fresh manifest')
    negative('fresh manifest wrong payload identity',lambda o,a:manifest_change(lambda m:m['candidate_identity'].update(payload_sha256='0'*64)),'fresh manifest')
    negative('fresh manifest log missing',lambda o,a:(fixture/'.artifacts/test.log').unlink(),'log mismatch')
    write_manifest(target,declaration)
    negative('fresh manifest falsely claims Live',lambda o,a:manifest_change(lambda m:m.update(live_provider='PASS')),'must not claim')
    reset(); (artifact/'verification.json').unlink()
    assert verify(real_done,root=fixture,owner_decision=decision)
    checks_run.append('fresh manifest absent')
    write_manifest(target,declaration)
    reset(); (fixture/DECLARATION).unlink()
    assert any('stale fingerprint' in e for e in verify(real_done,root=fixture,owner_decision=decision))
    checks_run.append('without declaration default remains strict (no blanket reuse)')
    reset()
    # Scope/type regressions exercise actual Git index and commits only in this temp repo.
    def rejects_describe(name, expected):
        try: describe(fixture)
        except (ValueError, subprocess.CalledProcessError) as error:
            assert expected in str(error), (name, str(error))
        else: raise AssertionError(name + ' incorrectly accepted')
        checks_run.append(name)
    for outside_path in ('.github/workflows/unreviewed.yml', 'docs/unreviewed.md'):
        outside=fixture/outside_path
        outside.write_text('TEST FIXTURE ONLY: outside approved payload\n')
        rejects_describe('outside '+outside_path+' untracked', 'outside payload')
        subprocess.run(['git','-C',str(fixture),'add',outside_path],check=True)
        rejects_describe('outside '+outside_path+' staged', 'outside payload')
        subprocess.run(['git','-C',str(fixture),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                        'commit','--quiet','-m','TEST FIXTURE ONLY outside scope'],check=True)
        rejects_describe('outside '+outside_path+' committed', 'outside payload')
        subprocess.run(['git','-C',str(fixture),'checkout','--quiet','--detach',IMPLEMENTATION_BASE],check=True)
        reset()
    for kind in ('delete', 'content', 'mode'):
        outside=fixture/'README.md'
        original=outside.read_bytes()
        if kind=='delete':outside.unlink()
        elif kind=='content':outside.write_bytes(original+b'\nTEST ONLY changed\n')
        else:outside.chmod(0o755)
        rejects_describe('outside tracked README '+kind+' worktree', 'deleted' if kind=='delete' else 'outside payload')
        subprocess.run(['git','-C',str(fixture),'add','README.md'],check=True)
        outside.write_bytes(original);outside.chmod(0o644)
        rejects_describe('outside tracked README '+kind+' index', 'outside payload')
        subprocess.run(['git','-C',str(fixture),'restore','--staged','README.md'],check=True)
    outside=fixture/'README.md'
    subprocess.run(['git','-C',str(fixture),'update-index','--chmod=+x','README.md'],check=True)
    subprocess.run(['git','-C',str(fixture),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                    'commit','--quiet','-m','TEST ONLY committed mode'],check=True)
    rejects_describe('outside tracked README committed mode', 'outside payload')
    outside.chmod(0o755)  # Match the temporary HEAD before safely returning to base.
    subprocess.run(['git','-C',str(fixture),'checkout','--quiet','--detach',IMPLEMENTATION_BASE],check=True)
    outside.chmod(0o644);reset()
    staged = fixture/'scripts/README.md'
    staged.write_text('TEST ONLY third staged version\n')
    subprocess.run(['git','-C',str(fixture),'add','scripts/README.md'],check=True)
    staged.write_bytes(saved['scripts/README.md'])
    rejects_describe('third index version differs from base and worktree', 'index/worktree')
    subprocess.run(['git','-C',str(fixture),'restore','--staged','scripts/README.md'],check=True)
    subprocess.run(['git','-C',str(fixture),'add',*PAYLOAD,DECLARATION],check=True)
    assert describe(fixture)==declaration
    checks_run.append('exact candidate index plus worktree supported')
    subprocess.run(['git','-C',str(fixture),'restore','--staged',*PAYLOAD,DECLARATION],check=True)
    attributes = Path(subprocess.check_output(['git','-C',str(fixture),'rev-parse','--absolute-git-dir'],text=True).strip())/'info/attributes'
    attributes.parent.mkdir(exist_ok=True)
    attributes.write_text('README.md export-ignore\n')
    import verify_doc_maintenance as maintenance
    assert 'README.md' in maintenance.tree(fixture,IMPLEMENTATION_BASE)
    (fixture/'README.md').write_text('TEST altered filtered baseline\n')
    rejects_describe('export-ignore cannot hide changed baseline path', 'outside payload')
    (fixture/'README.md').write_bytes(maintenance.tree(fixture,IMPLEMENTATION_BASE)['README.md'])
    attributes.unlink()
    for path in ('scripts/verify_doc_maintenance.py', DECLARATION, 'MacSoul/Models/MacSoulModels.swift'):
        original=(fixture/path).read_bytes(); targetfile=artifact/'ignored-link-target'
        targetfile.write_bytes(original);(fixture/path).unlink();(fixture/path).symlink_to(targetfile)
        rejects_describe('symlink rejected: '+path, 'symlink')
        (fixture/path).unlink();(fixture/path).write_bytes(original)
    # Decision identity is external to the payload and bound by the fresh manifest.
    pending=dict(decision,decision='PENDING',review_reference=None)
    (fixture/OWNER_DECISION).write_text(json.dumps(pending)+'\n')
    manifest=write_manifest(target,declaration)
    assert any('PENDING_FINAL_OWNER_DECISION' in e for e in verify(real_done,root=fixture,owner_decision=pending))
    checks_run.append('fixed PENDING record refuses production coverage')
    pendingbytes=(fixture/OWNER_DECISION).read_bytes()
    (fixture/OWNER_DECISION).unlink();(fixture/OWNER_DECISION).symlink_to(artifact/'ignored-link-target')
    rejects_describe('decision symlink rejected', 'symlink')
    (fixture/OWNER_DECISION).unlink();(fixture/OWNER_DECISION).write_bytes(pendingbytes)
    badrecord=dict(pending,to_fingerprint='0'*64)
    (fixture/OWNER_DECISION).write_text(json.dumps(badrecord))
    assert any('record identity' in e for e in verify(real_done,root=fixture,owner_decision=badrecord))
    checks_run.append('fixed decision wrong identity rejected')
    (fixture/OWNER_DECISION).write_text(json.dumps(decision))
    denied=subprocess.run([sys.executable,str(fixture/'scripts/verify_progress.py')],capture_output=True,text=True)
    assert denied.returncode==2 and 'test fixture is not a production' in denied.stderr
    checks_run.append('production CLI refuses isolated ACCEPTED fixture')
    # A later decision-only recording must work after the PENDING candidate is
    # committed, without changing payload/declaration. Commit only this fixture.
    (fixture/OWNER_DECISION).write_bytes(pendingbytes)
    manifest=write_manifest(target,declaration)
    denied=subprocess.run([sys.executable,str(fixture/'scripts/verify_progress.py')],capture_output=True,text=True)
    assert denied.returncode==1 and 'PENDING_FINAL_OWNER_DECISION' in denied.stdout
    checks_run.append('normal ledger default fixed PENDING record is refused')
    subprocess.run(['git','-C',str(fixture),'add',*PAYLOAD,DECLARATION,OWNER_DECISION],check=True)
    subprocess.run(['git','-C',str(fixture),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid',
                    'commit','--quiet','-m','TEST FIXTURE ONLY PENDING candidate'],check=True)
    (fixture/OWNER_DECISION).write_text(json.dumps(decision))
    assert maintenance.integrity(fixture)[0]==declaration
    checks_run.append('committed PENDING candidate supports isolated decision-only record update')
    (fixture/OWNER_DECISION).write_bytes(pendingbytes)
    subprocess.run(['git','-C',str(fixture),'checkout','--quiet','--detach',IMPLEMENTATION_BASE],check=True)
    reset()
    if (fixture/OWNER_DECISION).exists(): (fixture/OWNER_DECISION).unlink()
    manifest=write_manifest(target,declaration)
    # Reproduce the committed descendant shapes from Push and synthetic-merge CI.
    # Local TEST ONLY commits; neither fixed base has an advertised branch ref.
    source = Path(directory)/'topology-source'
    subprocess.run(['git','init','--quiet',str(source)],check=True)
    subprocess.run(['git','-C',str(source),'fetch','--quiet','--update-shallow',
                    '--no-tags',str(ROOT),BASELINE,IMPLEMENTATION_BASE],check=True)
    subprocess.run(['git','-C',str(source),'checkout','--quiet','--detach',IMPLEMENTATION_BASE],check=True)
    subprocess.run(['git','-C',str(source),'switch','--quiet','-c','fixture-feature'],check=True)
    for path in set(PAYLOAD)|{DECLARATION}:
        (source/path).parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(ROOT/path,source/path)
    subprocess.run(['git','-C',str(source),'add',*PAYLOAD,DECLARATION],check=True)
    identity=['-c','user.name=Fixture','-c','user.email=fixture@example.invalid']
    subprocess.run(['git','-C',str(source),*identity,'commit','--quiet','-m','TEST ONLY descendant candidate'],check=True)
    feature=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
    candidate_tree=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD^{tree}'],text=True).strip()
    merge=subprocess.check_output(['git','-C',str(source),*identity,'commit-tree',candidate_tree,
                                  '-p',IMPLEMENTATION_BASE,'-p',feature],input='TEST ONLY synthetic merge\n',text=True).strip()
    for scenario,revision in (('feature-descendant',feature),('detached-synthetic-merge',merge)):
        shallow=Path(directory)/('shallow-'+scenario)
        subprocess.run(['git','init','--quiet',str(shallow)],check=True)
        subprocess.run(['git','-C',str(shallow),'fetch','--quiet','--depth','1','--no-tags',str(source),revision],check=True)
        subprocess.run(['git','-C',str(shallow),'checkout','--quiet','--detach','FETCH_HEAD'],check=True)
        if scenario=='feature-descendant':
            subprocess.run(['git','-C',str(shallow),'switch','--quiet','-c','fixture-feature'],check=True)
        assert subprocess.check_output(['git','-C',str(shallow),'branch','--list','main'])==b''
        assert subprocess.check_output(['git','-C',str(shallow),'rev-parse','--is-shallow-repository'],text=True).strip()=='true'
        assert not (shallow/'.git/objects/info/alternates').exists()
        missing=verify(real_done,root=shallow,owner_decision=decision)
        assert any('missing fixed baseline object: '+BASELINE in e for e in missing),missing
        subprocess.run(['git','-C',str(shallow),'fetch','--quiet','--update-shallow',
                        '--no-tags',str(ROOT),BASELINE,IMPLEMENTATION_BASE],check=True)
        assert maintenance.integrity(shallow)[0]==declaration
        # Prepared objects exist, but no refs advertise either exact fixed base.
        refs=subprocess.check_output(['git','-C',str(shallow),'show-ref'],text=True) if scenario=='feature-descendant' else ''
        assert BASELINE not in refs and IMPLEMENTATION_BASE not in refs
        legacy=Path(directory)/('legacy-'+scenario)
        subprocess.run(['git','clone','--quiet','--no-local','--no-checkout',str(shallow),str(legacy)],check=True)
        subprocess.run(['git','-C',str(legacy),'fetch','--quiet','--update-shallow','--no-tags',str(shallow),BASELINE],check=True)
        assert subprocess.run(['git','-C',str(legacy),'cat-file','-e',IMPLEMENTATION_BASE],capture_output=True).returncode!=0
        failed=subprocess.run(['git','-C',str(legacy),'checkout','--quiet','--detach',IMPLEMENTATION_BASE],capture_output=True,text=True)
        assert failed.returncode==128 and 'unable to read tree' in failed.stderr,(scenario,failed)
        repaired=Path(directory)/('repaired-'+scenario)
        initial_fixture(shallow,repaired)
        assert subprocess.check_output(['git','-C',str(repaired),'rev-parse','HEAD'],text=True).strip()==IMPLEMENTATION_BASE
        assert tree_entries(repaired,BASELINE) and tree_entries(repaired,IMPLEMENTATION_BASE)
        checks_run.append('shallow '+scenario+': legacy missing implementation checkout fails 128; repaired exact objects/checkout PASS (no alternates/main)')
        # The parent itself also supports actual complete done-evidence validation.
        shutil.copytree(artifact,shallow/'.artifacts')
        receipt=json.loads((shallow/'.artifacts/verification.json').read_text());receipt['git_revision']=revision
        (shallow/'.artifacts/verification.json').write_text(json.dumps(receipt))
        assert not verify(real_done,root=shallow,owner_decision=decision)
    # A wrong commit object is refused, rather than succeeding at clone alone.
    try: tree_entries(fixture,'0'*40)
    except ValueError as error: assert 'missing fixed baseline object' in str(error)
    else: raise AssertionError('wrong fixed commit unexpectedly accepted')
    checks_run.append('wrong fixed commit object explicitly rejected')
    # Integrity must recompute baseline bytes, not trust its declaration fingerprint.
    from unittest.mock import patch
    import verify_doc_maintenance as maintenance
    actual_tree=maintenance.tree
    def mismatched_tree(root,revision):
        value=actual_tree(root,revision)
        if revision==BASELINE:value['scripts/fingerprint.py']+=b'\n# TEST corrupted baseline\n'
        return value
    with patch.object(maintenance,'tree',side_effect=mismatched_tree):
        assert any('baseline fingerprint mismatch' in e for e in verify(real_done,root=fixture,owner_decision=decision))
    checks_run.append('baseline full-input fingerprint mismatch')
    # Real generator scenarios use copied ledger data, never actual tasks.json.
    scenario_root=Path(directory)/'generator';(scenario_root/'scripts').mkdir(parents=True);(scenario_root/'docs').mkdir()
    shutil.copyfile(ROOT/'scripts/generate_status.py',scenario_root/'scripts/generate_status.py')
    def generator_case(name,mutator,expect):
        data=copy.deepcopy(real_done);mutator(data);(scenario_root/'tasks.json').write_text(json.dumps(data))
        subprocess.run([sys.executable,str(scenario_root/'scripts/generate_status.py')],check=True)
        output=(scenario_root/'docs/STATUS.md').read_text();assert expect(output),name
        checks_run.append('generator '+name)
    generator_case('closed',lambda o:None,lambda s:'48/48 done；已闭合' in s and '51 done，8 verifying' in s)
    generator_case('active',lambda o:next(t for t in o['tasks'] if t['id']=='D7-07').update(status='verifying'),lambda s:'47/48 done；未全部闭合' in s and 'Day 7 原始任务尚未全部关闭' in s)
    generator_case('not started',lambda o:[t.update(status='todo') for t in o['tasks'] if t['id'].startswith('D7-')],lambda s:'Day 7 尚未开始' in s and 'Day 7 原始任务已按账本关闭' not in s)
    generator_case('all closed',lambda o:[t.update(status='done') for t in o['tasks']],lambda s:'59 done，0 verifying' in s and len(s.split('## 未完成任务')[1].strip().splitlines())==2)
    # Exercise the SAME checked-in runner and real ledger/maintenance validator.
    # Only expensive command outcomes and the human-governance reader are injected
    # in this temporary repo. No production switch accepts fixture authorization.
    import os
    runner_bin=artifact/'runner-bin';runner_bin.mkdir()
    xcode=runner_bin/'xcodebuild'
    xcode.write_text('#!/bin/sh\nprintf "%s\\n" "TEST_FIXTURE_ONLY simulated xcodebuild outcome"\n')
    xcode.chmod(0o755)
    wrapper=runner_bin/'python3'
    wrapper.write_text('#!'+sys.executable+'\n'+'''import json,os,pathlib,runpy,sys
root=pathlib.Path.cwd()
if sys.argv[1:2]==['scripts/test_progress.py']:
    print('TEST_FIXTURE_ONLY simulated recursive progress outcome')
    sys.exit(0)
if sys.argv[1:2]==['scripts/verify_progress.py'] and not (root/'.artifacts/production-reader').exists():
    sys.path.insert(0,str(root/'scripts'))
    import verify_doc_maintenance as maintenance
    from unittest.mock import patch
    def fixture_reader(root,path=None):
        selected=root/maintenance.OWNER_DECISION
        if path is not None and pathlib.Path(path).absolute()!=selected.absolute():
            raise ValueError('fixture path mismatch')
        identity=maintenance.decision_identity(root)
        if identity is None:return None,None
        value=json.loads(maintenance.regular(root,maintenance.OWNER_DECISION)[1])
        if value.get('decision')=='ACCEPTED':
            assert str(value.get('review_reference','')).startswith('TEST_FIXTURE_ONLY')
        return value,identity
    sys.argv=sys.argv[1:]
    with patch.object(maintenance,'load_owner_decision',side_effect=fixture_reader):
        runpy.run_path(str(root/'scripts/verify_progress.py'),run_name='__main__')
else:
    os.execv(sys.executable,[sys.executable]+sys.argv[1:])
''')
    wrapper.chmod(0o755)
    runner_env=dict(os.environ,PATH=str(runner_bin)+os.pathsep+os.environ['PATH'])
    simulations=[]
    record=fixture/OWNER_DECISION
    production_marker=artifact/'production-reader'
    def runner_case(name,value,exit_code,reason=None,explicit=False,production=False,mutate=None):
        reset()
        if record.exists():record.unlink()
        if production_marker.exists():production_marker.unlink()
        if value is not None:record.write_text(json.dumps(value)+'\n')
        if production:production_marker.write_text('TEST ONLY: use unchanged production loader\n')
        if mutate:mutate()
        before=record.read_bytes() if record.exists() else None
        args=['./scripts/verify.sh']+(['--owner-decision',OWNER_DECISION] if explicit else [])
        result=subprocess.run(args,cwd=fixture,env=runner_env,capture_output=True,text=True,timeout=120)
        ledger_log=(artifact/'progress-verify.log').read_text()
        combined=result.stdout+result.stderr+ledger_log+(artifact/'doc-maintenance.log').read_text()
        assert result.returncode==exit_code,(name,result.returncode,combined)
        assert not reason or reason in combined,(name,combined)
        assert (record.read_bytes() if record.exists() else None)==before,'runner modified decision'
        receipt=artifact/'verification.json'
        if receipt.exists():
            observed=json.loads(receipt.read_text());ledger=observed['checks']['ledger']
            assert ledger['argv']==['python3','scripts/verify_progress.py']+(['--owner-decision',OWNER_DECISION] if value is not None or explicit else [])
            assert ledger['owner_decision_input']==maintenance.decision_identity(fixture)==observed['owner_decision_input']
            assert ledger['log_sha256']==sha((artifact/'progress-verify.log').read_bytes())
            if exit_code==0:
                assert all(c['exit_code']==0 and c['status']=='PASS' for c in observed['checks'].values())
                assert observed['working_tree_fingerprint']==target
                assert not verify(real_done,root=fixture,owner_decision=value)
        else:
            assert name=='illegal array; stale receipt not reused',name
            assert 'current verification manifest unavailable' in result.stderr
        simulations.append({'name':name,'runner_exit':result.returncode,'fixture_only':True,
                            'ledger_exit':observed['checks']['ledger']['exit_code'] if receipt.exists() else None})
    runner_case('no approval',None,1,'PENDING_FINAL_OWNER_DECISION')
    runner_case('explicit pending',pending,1,'PENDING_FINAL_OWNER_DECISION')
    runner_case('exact simulated approval default',decision,0)
    runner_case('exact simulated approval explicit',decision,0,explicit=True)
    runner_case('wrong target',dict(decision,to_fingerprint='0'*64),1,'record identity/schema mismatch')
    runner_case('illegal extra field',dict(decision,extra='forbidden'),1,'record identity/schema mismatch')
    runner_case('illegal array; stale receipt not reused',[],1,'must be an object')
    runner_case('production refuses test decision',decision,1,'test fixture is not a production',production=True)
    def bad_mapping():
        changed=copy.deepcopy(declaration);changed['evidence_mappings'][0]['task']='OUTSIDE'
        (fixture/DECLARATION).write_text(json.dumps(changed))
        value=dict(decision,declaration_sha256=sha((fixture/DECLARATION).read_bytes()))
        record.write_text(json.dumps(value))
    runner_case('mapping outside exact inventory',decision,1,'declaration/payload/fingerprint/mapping mismatch',mutate=bad_mapping)
    outside=fixture/'.github/workflows/runner-outside.yml'
    runner_case('approval cannot exempt unrelated path',decision,1,'outside payload',
                mutate=lambda:outside.write_text('TEST ONLY outside scope\n'))
    outside.unlink();record.unlink();reset()
    if production_marker.exists():production_marker.unlink()
    print(json.dumps({'runner_coverage_simulations':'PASS','fixture_only':True,
                      'injected_dependencies':['xcodebuild outcomes','recursive progress invocation',
                                               'isolated decision reader; production guard unchanged'],
                      'cases':simulations},indent=2))
    print(json.dumps({'status':'PASS','fixture_only':True,'done_tasks':51,'evidence_entries':70,
                      'cases':checks_run,'case_count':len(checks_run)},indent=2))

# Run the real shell entry with isolated dependencies. These are argument probes,
# not real passing checks or an authorization bypass in production code.
with tempfile.TemporaryDirectory(prefix='macsoul-runner-probe-') as directory:
    probe=Path(directory);(probe/'scripts').mkdir();(probe/'docs/evidence').mkdir(parents=True)
    subprocess.run(['git','init','--quiet',str(probe)],check=True)
    (probe/'fixture').write_text('TEST FIXTURE ONLY\n')
    subprocess.run(['git','-C',str(probe),'add','fixture'],check=True)
    subprocess.run(['git','-C',str(probe),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','--quiet','-m','fixture'],check=True)
    shutil.copyfile(ROOT/'scripts/verify.sh',probe/'scripts/verify.sh')
    (probe/'scripts/verify.sh').chmod(0o755)
    for name,log in (('doctor.sh','doctor.log'),('build.sh','build.log'),('test.sh','test.log')):
        (probe/'scripts'/name).write_text('#!/bin/zsh\nmkdir -p .artifacts\nprint "TEST PROBE ONLY" > .artifacts/'+log+'\n')
        (probe/'scripts'/name).chmod(0o755)
    for name in ('test_progress.py','verify-visual-assets.py'):
        (probe/'scripts'/name).write_text('print("TEST PROBE ONLY")\n')
    (probe/'scripts/fingerprint.py').write_text('print("TEST_PROBE_ONLY")\n')
    (probe/DECLARATION).write_text(json.dumps({'implementation_base':IMPLEMENTATION_BASE,'payload_sha256':'TEST_PROBE_ONLY'}))
    (probe/'scripts/verify_doc_maintenance.py').write_text("""import hashlib,json,pathlib
OWNER_DECISION='docs/evidence/v0.1.0-owner-decision.json'
def decision_identity(root):
 p=root/OWNER_DECISION
 if not p.exists():return None
 return {'path':OWNER_DECISION,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'decision':json.loads(p.read_text())['decision']}
if __name__=='__main__':print('TEST PROBE ONLY')
""")
    (probe/'scripts/verify_progress.py').write_text("""import json,pathlib,sys
from verify_doc_maintenance import decision_identity
pathlib.Path('.artifacts/argv-probe.json').write_text(json.dumps({'argv':sys.argv[1:],'identity':decision_identity(pathlib.Path.cwd())}))
print('TEST ARGUMENT PROBE ONLY, not ledger validation')
""")
    probes=[]
    for state,explicit in ((None,False),('PENDING',False),('ACCEPTED',False),('ACCEPTED',True)):
        record=probe/OWNER_DECISION
        if state is None:
            if record.exists():record.unlink()
        else:record.write_text(json.dumps({'decision':state,'review_reference':'TEST_FIXTURE_ONLY argument probe'}))
        args=['./scripts/verify.sh']+(['--owner-decision',OWNER_DECISION] if explicit else [])
        result=subprocess.run(args,cwd=probe,capture_output=True,text=True)
        assert result.returncode==0,(args,result.stderr)
        captured=json.loads((probe/'.artifacts/argv-probe.json').read_text())
        expected=['--owner-decision',OWNER_DECISION] if state else []
        assert captured['argv']==expected
        manifest=json.loads((probe/'.artifacts/verification.json').read_text())
        ledger=manifest['checks']['ledger']
        assert ledger['argv']==['python3','scripts/verify_progress.py']+expected
        assert ledger['owner_decision_input']==captured['identity']==manifest.get('owner_decision_input')
        assert ledger['exit_code']==0 and ledger['log_sha256']==sha((probe/'.artifacts/progress-verify.log').read_bytes())
        probes.append({'state':state,'explicit':explicit,'argv':captured['argv']})
    rejected=subprocess.run(['./scripts/verify.sh','--owner-decision','arbitrary.json'],cwd=probe,capture_output=True)
    assert rejected.returncode==2
    print(json.dumps({'runner_argument_probes':'PASS','fixture_only':True,'cases':probes,'wrong_path_exit':rejected.returncode},indent=2))
