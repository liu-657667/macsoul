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
day2=[t for t in data['tasks'] if t['id'] in ('D2-01','D2-02','D2-03','D2-04','D2-05','D2-06','D2-07')]
day2_started=any(t['status']!='todo' for t in day2)
system_details_started=any(t['status']!='todo' for t in day2 if t['id'] in ('D2-04','D2-05'))
day3=[t for t in data['tasks'] if t['id'].startswith('D3-')]
dev_started=any(t['status']!='todo' for t in day3 if t['id'] in ('D3-01','D3-02','D3-03','D3-07'))
dev_tasks=[t for t in day3 if t['id'] in ('D3-01','D3-02','D3-03')]
dev_accepted=len(dev_tasks)==3 and all(t['status']=='done' and t.get('human_ui_confirmation') for t in dev_tasks)
network_started=any(t['status']!='todo' for t in day3 if t['id'] in ('D3-04','D3-05','D3-06'))
network_accepted=network_started and all(t['status']=='done' for t in day3 if t['id'] in ('D3-04','D3-05','D3-06','D3-07'))
historical_ui=all(t.get('human_ui_confirmation') for t in data['tasks'] if t['id'] in ('A1','A3'))
dock_approved=any(t.get('dock_ui_confirmation') for t in data['tasks'] if t['id']=='VA-01')
phase_a_note=('Phase A 当前验收完成；按账本依赖继续，真实 Provider 未接入' if phase_a_done else
              'Phase A 截图仅部分通过；当前 UI 可读性和外观仍待复核，真实 Provider 未接入' if historical_ui else
             '待 Phase A 人工验收后启动；真实 Provider 未接入')
if day2_started:
    phase_a_note=('Phase A 历史验收保持原状态；D2 已按负责人授权接入实时 CPU/内存/磁盘/电池/开发进程；AI、网络、开发环境 Provider 仍未接入'
                  if system_details_started else
                  'Phase A 历史验收保持原状态；D2 已按负责人授权开始 CPU/内存实时接入，其他 Provider 仍未接入')
if dev_started:
    phase_a_note=('Phase A 历史验收保持原状态；D2 系统监测与 D3 开发环境已验收；D3-07 的 Network wiring 待完成；AI 与网络 Provider 未接入'
                  if dev_accepted else 'Phase A 历史验收保持原状态；D2 系统监测已验收；D3 开发环境采集已实现、待人工验收；AI 与网络 Provider 未接入')
if network_started:
    phase_a_note=('Phase A 历史验收保持原状态；D2 系统与 D3 开发环境已验收；D3 Network 已实现，人工 UI 待验收；AI Provider 未接入' if not network_accepted else 'Phase A 历史验收保持原状态；D2 系统与 D3 开发环境/网络已验收；AI Provider 未接入')
manual_note=('负责人已确认当前 Phase A Mock 双入口' if phase_a_done and historical_ui else
             '浅色 Week-only 与深色中文菜单栏已截图复核；Dock 已由负责人通过；本轮修订版与其余 Soul、完整交互仍待人工验收' if historical_ui and dock_approved else
             '浅色 Week-only 与深色中文菜单栏已截图复核；Dock、其余五种 Soul、完整交互仍待人工验收' if historical_ui else '待负责人确认')
if day2_started and all(t.get('human_ui_confirmation') for t in day2 if t['id'] in ('D2-01', 'D2-02', 'D2-03', 'D2-06', 'D2-07')):
    manual_note='负责人已确认实时 CPU、内存数值、Overview/System/Menu Bar 同步、窗口开关 5 次、菜单栏反复打开及 Live/Mock 边界'
    manual_note += ('；Memory Pressure 自然 Warning 已观察，Critical 未观察但不阻塞本轮验收'
                    if next(t for t in day2 if t['id']=='D2-03')['status']=='done' else
                    '；Memory Pressure 自然事件仍 VERIFYING')
if system_details_started:
    manual_note += ('；磁盘与电池已验收' if next(t for t in day2 if t['id']=='D2-04')['status']=='done'
                    else '；磁盘与电池待负责人验收')
    manual_note += ('；进程 CPU 动态待负责人验收' if next(t for t in day2 if t['id']=='D2-05')['status']=='verifying'
                    else '；开发进程已验收')
if dev_started:
    manual_note += ('；D3 runtime contexts、开发端口过滤/聚合、native Table 与复制操作已由负责人验收；停止命令仅复制、不执行'
                    if dev_accepted else '；D3 开发环境运行时与监听端口界面待负责人验收')
if network_started:
    manual_note += ('；D3 Network 人工 UI 已验收' if network_accepted else '；D3 Network 人工 UI 待负责人验收，实机只读观察不代替 UI 验收')
lines=['# MacSoul 当前状态','', '> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。','',
       f'- Phase A: '+', '.join(f"{t['id']}={t['status']}" for t in data['tasks'] if t['id'].startswith('A')),
       f'- 原始计划验收：{points}/76 点（{points/76:.1%}）',
       f'- 已批准调整计划验收：{current_done}/{current} 点（{current_done/current if current else 0:.1%}）；当前无批准范围变更',
       '- 增量任务：' + (', '.join(f"{t['id']}={t['status']}" for t in additional) if additional else '无'),
       '- 后续产品任务：' + phase_a_note,
       '- D2 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in day2),
       '- D3 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in day3),
       '- Build/Unit：' + ('见 `reports/day-3-network-2026-10-02.md` 与 `.artifacts/verification.json`' if network_started else '见 `reports/day-3-dev-environment-2026-09-29.md` 与 `.artifacts/verification.json`' if dev_started else '见 `reports/day-2-system-details-2026-09-29.md` 与 `.artifacts/verification.json`' if system_details_started else '见 `reports/day-2-system-soul-memory-closeout-2026-09-29.md` 与 `.artifacts/verification.json`' if day2_started else '见 `reports/phase-a-visual-closeout-2026-09-28.md` 与 `.artifacts/verification.json`'),
       '- Manual UI：' + manual_note + '；Performance/真实 AI Provider：NOT_RUN','',
       '## 未完成任务','', '| ID | 原始日 | 点数 | 状态 | 任务 |','|---|---:|---:|---|---|']
for t in original:
    if t['status']!='done': lines.append(f"| {t['id']} | {t['original_day']} | {t['original_points']} | {t['status']} | {t['title'].replace('|','/')} |")
(root/'docs/STATUS.md').write_text('\n'.join(lines)+'\n')
