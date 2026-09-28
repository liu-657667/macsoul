# MacSoul 当前状态

> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。

- Phase A: A4=done, A3=verifying, A2=done, A1=verifying
- 原始计划验收：10/76 点（13.2%）
- 已批准调整计划验收：10/76 点（13.2%）；当前无批准范围变更
- 增量任务：VA-01=verifying, QC-01=verifying, UI-01=verifying
- 后续产品任务：Phase A 截图仅部分通过；当前 UI 可读性和外观仍待复核，真实 Provider 未接入
- Build/Unit：见 `reports/phase-a-ui-review.md` 与 `.artifacts/verification.json`
- Manual UI：浅色 Week-only 与深色中文菜单栏已截图复核；Dock、其余五种 Soul、完整交互仍待人工验收，见 `reports/phase-a-ui-review.md`；Performance/Live Provider：NOT_RUN

## 未完成任务

| ID | 原始日 | 点数 | 状态 | 任务 |
|---|---:|---:|---|---|
| D2-01 | 2 | 2 | todo | Central SensorHub / lifecycle-aware scheduling. |
| D2-02 | 2 | 2 | todo | CPU native provider + shared snapshot. |
| D2-03 | 2 | 2 | todo | Memory + pressure provider. |
| D2-04 | 2 | 1 | todo | Disk + battery provider. |
| D2-05 | 2 | 2 | todo | Top developer process summary. |
| D2-06 | 2 | 2 | todo | Soul state machine: CPU/memory thresholds, hysteresis, cooldown, recovery. |
| D2-07 | 2 | 1 | todo | Unit tests + real System/Overview/Menu Bar wiring. |
| D3-01 | 3 | 2 | todo | Safe cancellable ShellRunner. |
| D3-02 | 3 | 2 | todo | Java/Node/Python/Go detection + cache. |
| D3-03 | 3 | 2 | todo | Listening ports + process/PID mapping. |
| D3-04 | 3 | 2 | todo | Network path + public IP adapter. |
| D3-05 | 3 | 2 | todo | shell/system proxy + tunnel/VPN hints. |
| D3-06 | 3 | 1 | todo | connectivity probes with backoff/disable. |
| D3-07 | 3 | 1 | todo | tests/fixtures + Overview wiring. |
| D4-01 | 4 | 3 | todo | Codex app-server quota adapter: initial read + update path, 5h/week mapping. |
| D4-02 | 4 | 1 | todo | Codex reconnect/stale/unavailable handling + fixtures. |
| D4-03 | 4 | 2 | todo | Claude Code stable-source spike and adapter boundary. |
| D4-04 | 4 | 1 | todo | If supported source exists: 5h/week parser/bridge; otherwise honest unavailable state. |
| D4-05 | 4 | 2 | todo | AI Coding page + Menu Bar live quota summary. |
| D4-06 | 4 | 1 | todo | 95% deduplicated notifications/Soul events. |
| D4-07 | 4 | 1 | todo | provider tests. |
| D5-01 | 5 | 2 | todo | On-demand Cleaner scan framework; no background recursive scans. |
| D5-02 | 5 | 2 | todo | At least 3 useful developer cache categories with size/risk/explanation. |
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
