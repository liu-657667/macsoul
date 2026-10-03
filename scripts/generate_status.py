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
day4 = [t for t in data['tasks'] if t['id'].startswith('D4-')]
ai_started = any(t['status'] != 'todo' for t in day4)
ai_accepted = len(day4) == 7 and all(t['status'] == 'done' and t.get('human_ui_confirmation') for t in day4)
if ai_started:
    codex_observed = any(t.get('capability_observation', {}).get('read_supported') for t in day4)
    phase_a_note = ('Phase A 历史验收保持原状态；系统/开发环境/网络/Cleaner 已验收；D4 Codex Live 与 Claude honest unavailable 边界已由负责人验收；正式 Performance 未运行' if ai_accepted else
                   'Phase A 历史验收保持原状态；系统/开发环境/网络/Cleaner 已验收；AI 配额第二阶段映射与集成已实现，真实 MacSoul AI UI 待负责人验收'
                    if codex_observed else 'Phase A 历史验收保持原状态；系统/开发环境/网络/Cleaner 已验收；AI 配额架构与 fixtures 已实现，真实 Codex 观察待负责人授权')
    manual_note += ('；D4 Codex Live、Week-only 剩余配额、三入口同步、277 秒刷新及 Preview/Live 回切已由负责人验收；Claude unavailable 已验收；自然 quota 更新通知与真实 95% 事件未观察' if ai_accepted else
                   '；Codex 只读 capability 已观察，真实 MacSoul AI UI/跨客户端事件尚未验收'
                    if codex_observed else '；AI Quota 首阶段仅自动验证，真实账户与 UI 尚未验收')
cleaner_started = any(t['status'] != 'todo' for t in data['tasks'] if t['id'] in ('D5-01', 'D5-02'))
cleaner_tasks = [t for t in data['tasks'] if t['id'] in ('D5-01', 'D5-02')]
cleaner_accepted = len(cleaner_tasks) == 2 and all(t['status'] == 'done' and t.get('human_ui_confirmation') for t in cleaner_tasks)
if cleaner_started:
    manual_note += ('；Cleaner 真实只读扫描、内容预览与 Docker 只读查询已由负责人验收；Cleanup 未实现（设计边界）'
                    if cleaner_accepted else '；Cleaner 只读扫描／内容预览待负责人 UI/真实扫描验收')
lines=['# MacSoul 当前状态','', '> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。','',
       f'- Phase A: '+', '.join(f"{t['id']}={t['status']}" for t in data['tasks'] if t['id'].startswith('A')),
       f'- 原始计划验收：{points}/76 点（{points/76:.1%}）',
       f'- 已批准调整计划验收：{current_done}/{current} 点（{current_done/current if current else 0:.1%}）；当前无批准范围变更',
       '- 增量任务：' + (', '.join(f"{t['id']}={t['status']}" for t in additional) if additional else '无'),
       '- 后续产品任务：' + phase_a_note,
       '- D2 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in day2),
       '- D3 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in day3),
       '- D4 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in day4),
       '- D5 本轮：' + ', '.join(f"{t['id']}={t['status']}" for t in data['tasks'] if t['id'].startswith('D5-')),
       '- 执行顺序：' + ('负责人批准 Cleaner 只读扫描先于 AI 配额；原始计划、点数和依赖历史保留' if cleaner_started else '沿用原始计划；按负责人本轮授权执行'),
       '- Build/Unit：' + ('见 `reports/day-4-ai-quota-2026-10-03.md` 与 `.artifacts/verification.json`' if ai_started else '见 `reports/day-5-cleaner-readonly-2026-10-02.md` 与 `.artifacts/verification.json`' if cleaner_started else '见 `reports/day-3-network-2026-10-02.md` 与 `.artifacts/verification.json`' if network_started else '见 `reports/day-3-dev-environment-2026-09-29.md` 与 `.artifacts/verification.json`' if dev_started else '见 `reports/day-2-system-details-2026-09-29.md` 与 `.artifacts/verification.json`' if system_details_started else '见 `reports/day-2-system-soul-memory-closeout-2026-09-29.md` 与 `.artifacts/verification.json`' if day2_started else '见 `reports/phase-a-visual-closeout-2026-09-28.md` 与 `.artifacts/verification.json`'),
       '- Manual UI：' + manual_note + ('；Performance、真实 sleep/wake、Claude subscription quota、App Store Connect privacy validation：NOT_RUN' if ai_accepted else '；Performance/真实 AI Provider：NOT_RUN'),'',
       '## 未完成任务','', '| ID | 原始日 | 点数 | 状态 | 任务 |','|---|---:|---:|---|---|']
for t in original:
    if t['status']!='done': lines.append(f"| {t['id']} | {t['original_day']} | {t['original_points']} | {t['status']} | {t['title'].replace('|','/')} |")
(root/'docs/STATUS.md').write_text('\n'.join(lines)+'\n')
