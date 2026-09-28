#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
data=json.loads((root/'tasks.json').read_text())
original=[t for t in data['tasks'] if t['original_day'] is not None]
done=[t for t in original if t['status']=='done']
points=sum(t['original_points'] for t in done)
current=sum(t['current_points'] for t in original if t['status']!='deferred' or t.get('scope_change_approval') is None)
current_done=sum(t['current_points'] for t in done)
lines=['# MacSoul 当前状态','', '> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。','',
       f'- Phase A: '+', '.join(f"{t['id']}={t['status']}" for t in data['tasks'] if t['id'].startswith('A')),
       f'- 原始计划验收：{points}/76 点（{points/76:.1%}）',
       f'- 已批准调整计划验收：{current_done}/{current} 点（{current_done/current if current else 0:.1%}）；当前无批准范围变更',
       '- 后续产品任务：待 Phase A 人工验收后启动；真实 Provider 未接入',
       '- Build/Unit：见 `reports/phase-a.md` 与 `.artifacts/verification.json`',
       '- Manual UI：待负责人确认；Performance/Live Provider：NOT_RUN','',
       '## 未完成任务','', '| ID | 原始日 | 点数 | 状态 | 任务 |','|---|---:|---:|---|---|']
for t in original:
    if t['status']!='done': lines.append(f"| {t['id']} | {t['original_day']} | {t['original_points']} | {t['status']} | {t['title'].replace('|','/')} |")
(root/'docs/STATUS.md').write_text('\n'.join(lines)+'\n')
