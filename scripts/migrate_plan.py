#!/usr/bin/env python3
"""One-time baseline migration; refuses to replace an existing ledger."""
from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parent.parent
out=root/'tasks.json'
if out.exists(): raise SystemExit('tasks.json already exists; refusing overwrite')
source=root/'docs/7-DAY-PLAN.md'
raw=source.read_text()
day=0; section='P0'; counts={}; tasks=[]
for line in raw.splitlines():
    m=re.match(r'## Day (\d+)',line)
    if m: day=int(m.group(1)); counts[day]=0; section='P0'; continue
    if line.strip() in ('P0:','P1:','P2:'): section=line.strip()[:-1]; continue
    m=re.match(r'- \[ \] \((\d+)\) (.+)',line)
    if not m or not day: continue
    points=int(m.group(1)); counts[day]+=1
    title=m.group(2)
    id=f'D{day}-{counts[day]:02d}'
    depends=[] if day==1 else [f'D{day-1}-01']
    tasks.append({'id':id,'title':title,'priority':section,'original_day':day,'planned_day':day,
      'original_points':points,'current_points':points,'scope':'original seven-day plan','depends_on':depends,
      'acceptance':[{'id':id+'-A','description':title,'kind':'implementation'}],
      'status':'todo','evidence':[],'blocker':None,'scope_change_approval':None})
phase=[
 ('A1','统一产品设计和双入口四窗口显示','verifying',['A1-CONTRACT','A1-UI']),
 ('A2','可重复 Xcode 工程、构建和测试入口','verifying',['A2-BUILD','A2-UNIT']),
 ('A3','共享 Snapshot、Mock fixture 与状态契约','verifying',['A3-CONTRACT','A3-UI']),
 ('A4','任务账本与证据验证','verifying',['A4-LEDGER','A4-NEGATIVE'])]
for id,title,status,acceptance in phase:
    tasks.insert(0,{'id':id,'title':title,'priority':'P0','original_day':None,'planned_day':1,
      'original_points':0,'current_points':0,'scope':'Phase A hardening; zero additional baseline points',
      'depends_on':[],'acceptance':[{'id':a,'description':a,'kind':'command' if a not in ('A1-UI','A3-UI') else 'manual-ui'} for a in acceptance],
      'status':status,'evidence':[],'blocker':None,'scope_change_approval':None})
assert sum(t['original_points'] for t in tasks)==76
out.write_text(json.dumps({'schema_version':1,'baseline':{'source':'docs/7-DAY-PLAN.md','sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'original_points':76,'owner_approved_change':False},
    'tasks':tasks,'change_log':[]},ensure_ascii=False,indent=2)+'\n')
print(f'migrated {len(tasks)-4} original tasks, 76 points, plus 4 Phase A tasks')
