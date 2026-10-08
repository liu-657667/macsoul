# MacSoul 当前状态

> 此页由 `python3 scripts/generate_status.py` 从 `tasks.json` 生成；只编辑账本。

- Phase A: A4=done, A3=verifying, A2=done, A1=verifying
- 原始计划任务：48/48 done；已闭合
- 原始计划验收：76/76 点（100.0%）
- 全账本：59 项；51 done，8 verifying（原计划与增量分开计数）
- 维护证据覆盖须经精确 Owner 决定；此页显示原账本状态，不代表候选例外已启用。
- 发布、仓库集成与未执行边界见 [发行说明](RELEASE.md) 和 [当前报告导航](../reports/FINAL.md)；不从任务 done 推断公开发行。
- 已批准调整计划验收：76/76 点（100.0%）；当前无批准范围变更
- 增量任务：VA-01=verifying, QC-01=verifying, UI-01=verifying, VIS-01=done, VIS-02=verifying, VIS-03=verifying, VIS-04=verifying
- 后续产品任务：Day 7 原始任务已按账本关闭；增量任务保持各自状态，按 Owner 当前授权维护
- D2 本轮：D2-01=done, D2-02=done, D2-03=done, D2-04=done, D2-05=done, D2-06=done, D2-07=done
- D3 本轮：D3-01=done, D3-02=done, D3-03=done, D3-04=done, D3-05=done, D3-06=done, D3-07=done
- D4 本轮：D4-01=done, D4-02=done, D4-03=done, D4-04=done, D4-05=done, D4-06=done, D4-07=done
- D5 本轮：D5-01=done, D5-02=done, D5-03=done, D5-04=done, D5-05=done, D5-06=done
- D6 本轮：D6-01=done, D6-02=done, D6-03=done, D6-04=done, D6-05=done, D6-06=done, D6-07=done
- D7 本轮：D7-01=done, D7-02=done, D7-03=done, D7-04=done, D7-05=done, D7-06=done, D7-07=done, D7-08=done
- 执行顺序：负责人批准 Cleaner 只读扫描先于 AI 配额；原始计划、点数和依赖历史保留
- Build/Unit：见 `reports/day-7-release-closeout-2026-10-07.md` 与 `.artifacts/verification.json`
- Manual UI：既有人工验收归属和未执行边界见 [Day 7 closeout](../reports/day-7-release-closeout-2026-10-07.md)；任务 done 不等于本轮重新执行 UI/Live/性能；性能原始结果与 scoped acceptance 见 Day 7 报告，不由本页推断新 PASS

## 未完成任务

| ID | 原始日 | 点数 | 状态 | 任务 |
|---|---:|---:|---|---|
| A3 | 增量 | 0 | verifying | 共享 Snapshot、Mock fixture 与状态契约 |
| A1 | 增量 | 0 | verifying | 统一产品设计和双入口动态配额窗口显示 |
| VA-01 | 增量 | 0 | verifying | Integrate supplied visual assets into the existing Mock App. |
| QC-01 | 增量 | 0 | verifying | Apply owner-approved dynamic AI quota window contract to Mock App. |
| UI-01 | 增量 | 0 | verifying | Phase A 菜单栏与 Overview 可读性、局部外观和中英界面修订 |
| VIS-02 | 增量 | 0 | verifying | 双入口倒计时共享时钟 |
| VIS-03 | 增量 | 0 | verifying | Soul Mock 场景文案 |
| VIS-04 | 增量 | 0 | verifying | 深色辅助文字与临界态辨识 |
