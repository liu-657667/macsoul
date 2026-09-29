#!/usr/bin/env python3
import json
from pathlib import Path
root=Path(__file__).resolve().parent.parent
data=json.loads((root/'tasks.json').read_text())
original=[t for t in data['tasks'] if t['original_day'] is not None]
additional=[t for t in data['tasks'] if t['original_day'] is None and not t['id'].startswith('A')]
done=[t for t in original if t['status']=='done']
points=sum(t['original_points'] for t in done)
current=sum(t['current_points'] for t in original if t['status']!='deferred' or t.get('scope_change_approval') is None)
current_done=sum(t['current_points'] for t in done)
phase_a=[t for t in data['tasks'] if t['id'].startswith('A')]
phase_a_done=all(t['status']=='done' for t in phase_a)
day2=[t for t in data['tasks'] if t['id'] in ('D2-01','D2-02','D2-03','D2-06','D2-07')]
day2_started=any(t['status']!='todo' for t in day2)
historical_ui=all(t.get('human_ui_confirmation') for t in data['tasks'] if t['id'] in ('A1','A3'))
dock_approved=any(t.get('dock_ui_confirmation') for t in data['tasks'] if t['id']=='VA-01')
phase_a_note=('Phase A 当前验收完成；按账本依赖继续，真实 Provider 未接入' if phase_a_done else
              'Phase A 截图仅部分通过；当前 UI 可读性和外观仍待复核，真实 Provider 未接入' if historical_ui else
             '待 Phase A 人工验收后启动；真实 Provider 未接入')
if day2_started:
    phase_a_note='Phase A 历史验收保持原状态；D2 已按负责人授权开始 CPU/内存实时接入，其他 Provider 仍未接入'
manual_note=('负责人已确认当前 Phase A Mock 双入口' if phase_a_done and historical_ui else
             '浅色 Week-only 与深色中文菜单栏已截图复核；Dock 已由负责人通过；本轮修订版与其余 Soul、完整交互仍待人工验收' if historical_ui and dock_approved else
             '浅色 Week-only 与深色中文菜单栏已截图复核；Dock、其余五种 Soul、完整交互仍待人工验收' if historical_ui else '待负责人确认')
if day2_started and all(t.get('human_ui_confirmation') for t in day2 if t['id'] in ('D2-01', 'D2-02', 'D2-03', 'D2-06', 'D2-07')):
    manual_note='负责人已确认实时 CPU、内存数值、Overview/System/Menu Bar 同步、窗口开关 5 次、菜单栏反复打开及 Live/Mock 边界；Memory Pressure 自然事件仍 VERIFYING'
lines=['# MacSoul 当前状态','', '> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。','',
       f'- Phase A: '+', '.join(f"{t['id']}={t['status']}" for t in data['tasks'] if t['id'].startswith('A')),
       f'- 原始计划验收：{points}/76 点（{points/76:.1%}）',
       f'- 已批准调整计划验收：{current_done}/{current} 点（{current_done/current if current else 0:.1%}）；当前无批准范围变更',
       '- 增量任务：' + (', '.join(f"{t['id']}={t['status']}" for t in additional) if additional else '无'),
       '- 后续产品任务：' + phase_a_note,
       '- D2 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in day2),
       '- Build/Unit：' + ('见 `reports/day-2-system-soul-memory-closeout-2026-09-29.md` 与 `.artifacts/verification.json`' if day2_started else '见 `reports/phase-a-visual-closeout-2026-09-28.md` 与 `.artifacts/verification.json`'),
       '- Manual UI：' + manual_note + '；Performance/真实 AI Provider：NOT_RUN','',
       '## 未完成任务','', '| ID | 原始日 | 点数 | 状态 | 任务 |','|---|---:|---:|---|---|']
for t in original:
    if t['status']!='done': lines.append(f"| {t['id']} | {t['original_day']} | {t['original_points']} | {t['status']} | {t['title'].replace('|','/')} |")
(root/'docs/STATUS.md').write_text('\n'.join(lines)+'\n')
