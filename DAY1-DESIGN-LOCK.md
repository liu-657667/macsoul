# Day 1 设计锁定 — 当前入口

权威产品设计见 `docs/SCOPE.md`、`docs/DESIGN.md` 和 `docs/INTEGRATION-NOTES.md`。
本文件不再维护第二套设计。原版本保存在 `reference/originals/day1/DAY1-DESIGN-LOCK.md`。

首次交付：原生主窗口 + Menu Bar + Mock 数据展示；先执行 Review Phase A。
**主窗口和 Menu Bar 必须同时显示 Codex 5h、Codex Week、Claude 5h、Claude Week。**
每项显示已用百分比、可用的重置时间，并独立支持缺失/过期；不能用 0% 代替无数据。

Phase A 已在源码中移除原始硬编码并补齐 Menu Bar 周额度；构建与单测证据见 `reports/phase-a.md`。主窗口与 Menu Bar 仍需负责人分别进行人工验收。
此阶段不接真实扫描/配额、不做 Notch、不进行缓存删除；用户先确认 UI 和构建质量。
