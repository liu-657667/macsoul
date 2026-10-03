# MacSoul 当前状态

> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。

- Phase A: A4=done, A3=verifying, A2=done, A1=verifying
- 原始计划验收：49/76 点（64.5%）
- 已批准调整计划验收：49/76 点（64.5%）；当前无批准范围变更
- 增量任务：VA-01=verifying, QC-01=verifying, UI-01=verifying, VIS-01=done, VIS-02=verifying, VIS-03=verifying, VIS-04=verifying
- 后续产品任务：Phase A 历史验收保持原状态；系统/开发环境/网络/Cleaner 已验收；D4 Codex Live 与 Claude honest unavailable 边界已由负责人验收；正式 Performance 未运行
- D2 本轮：D2-01=done, D2-02=done, D2-03=done, D2-04=done, D2-05=done, D2-06=done, D2-07=done
- D3 本轮：D3-01=done, D3-02=done, D3-03=done, D3-04=done, D3-05=done, D3-06=done, D3-07=done
- D4 本轮：D4-01=done, D4-02=done, D4-03=done, D4-04=done, D4-05=done, D4-06=done, D4-07=done
- D5 本轮：D5-01=done, D5-02=done, D5-03=todo, D5-04=todo, D5-05=todo, D5-06=todo
- 执行顺序：负责人批准 Cleaner 只读扫描先于 AI 配额；原始计划、点数和依赖历史保留
- Build/Unit：见 `reports/day-4-ai-quota-2026-10-03.md` 与 `.artifacts/verification.json`
- Manual UI：负责人已确认实时 CPU、内存数值、Overview/System/Menu Bar 同步、窗口开关 5 次、菜单栏反复打开及 Live/Mock 边界；Memory Pressure 自然 Warning 已观察，Critical 未观察但不阻塞本轮验收；磁盘与电池已验收；开发进程已验收；D3 runtime contexts、开发端口过滤/聚合、native Table 与复制操作已由负责人验收；停止命令仅复制、不执行；D3 Network 人工 UI 已验收；D4 Codex Live、Week-only 剩余配额、三入口同步、277 秒刷新及 Preview/Live 回切已由负责人验收；Claude unavailable 已验收；自然 quota 更新通知与真实 95% 事件未观察；Cleaner 真实只读扫描、内容预览与 Docker 只读查询已由负责人验收；Cleanup 未实现（设计边界）；Performance、真实 sleep/wake、Claude subscription quota、App Store Connect privacy validation：NOT_RUN

## 未完成任务

| ID | 原始日 | 点数 | 状态 | 任务 |
|---|---:|---:|---|---|
| D5-03 | 5 | 2 | todo | Adaptive sampling: menu-bar-only vs visible page rates. |
| D5-04 | 5 | 2 | todo | sleep/wake/network lifecycle cancellation/restart review. |
| D5-05 | 5 | 2 | todo | first Instruments/performance pass and fixes. |
| D5-06 | 5 | 1 | todo | integration tests / manual failure-state checklist. |
| D6-01 | 6 | 2 | todo | Run reviewer across architecture/privacy/performance/tests. |
| D6-02 | 6 | 2 | todo | Fix all critical/high findings. |
| D6-03 | 6 | 1 | todo | accessibility + Reduce Motion + keyboard pass. |
| D6-04 | 6 | 1 | todo | offline, provider unavailable, malformed data validation. |
| D6-05 | 6 | 1 | todo | Launch at Login/settings polish. |
| D6-06 | 6 | 1 | todo | sustained idle/menu-bar performance validation. |
| D6-07 | 6 | 2 | todo | README/install/privacy/limitations/screenshots draft. |
| D7-01 | 7 | 2 | todo | full clean build + tests. |
| D7-02 | 7 | 2 | todo | regression pass on System/Soul/Network/Dev/AI/Cleaner. |
| D7-03 | 7 | 1 | todo | final performance sanity check. |
| D7-04 | 7 | 1 | todo | final privacy/log scan. |
| D7-05 | 7 | 1 | todo | version/license/changelog/contributing. |
| D7-06 | 7 | 1 | todo | release build packaging/signing/notarization plan or completed path available to the owner. |
| D7-07 | 7 | 1 | todo | final README/GIF/screenshots. |
| D7-08 | 7 | 1 | todo | write `reports/FINAL.md` with shipped/deferred/known limitations/next v0.2 items. |
