# Day 1 检查点

日期：2026-09-28（Asia/Shanghai）。状态以 `tasks.json` 为准。Phase A 的 A1–A4 已完成；负责人确认主窗口与 Menu Bar 的 Mock 四窗口，记录见 [界面验收补记](phase-a-owner-acceptance.md)。原七天计划 D1-01–D1-05 完成，9/76 点（11.8%）；没有调整点数、优先级或产品范围。

## 本次推进

- D1-05：整理共享间距、圆角和 Soul 尺寸 token；Card、MetricTile、QuotaRow、Overview 与 Menu Bar 复用 token。Overview 中的 Soul 文字表情改为静态 SwiftUI 矢量占位图；状态仍由旁边文字表达，无动画。
- D1-06：build 和 6 个 XCTest 已通过；已重启 Mock App 并在 Agent 可访问性树观察到新版 Overview。界面工具提供的截图只有低分辨率预览，待负责人提供更新后的主窗口截图并确认视觉后完成截图验收。
- 两个菜单栏图标来自同一机器上并存的不同构建副本。负责人授权退出测试副本后确认只剩一个图标；后续界面工具按名称又打开旧副本，现已退出。只运行固定验证入口并不会新增第二个图标。

## 验证

| 项目 | 状态 | 证据 |
|---|---|---|
| build | PASS | `./scripts/verify.sh` 退出 0；`.artifacts/build.log` |
| unit | PASS | 6 个 XCTest、0 失败；`.artifacts/test.log` |
| ledger | PASS | 52 项任务、原基线 76 点；`.artifacts/progress-verify.log` |
| manual UI：Phase A | PASS | 负责人确认，见 `reports/phase-a-owner-acceptance.md` |
| D1-05 新图形视觉复核 | PENDING | 新版 App 已打开，等待负责人查看更新后的主窗口 |
| performance | NOT_RUN | 未做 Release 及持续采样测量 |
| live provider | NOT_RUN | 仍是 Mock App |

当前工作树指纹见 `.artifacts/verification.json`；证据仅对应当前源码。下一项为 D1-06 的可复核截图和视觉确认，然后按账本依赖选择下一项。GitHub CI 工作流草案仍未推送，原因见 [仓库初始化记录](repository-setup.md)。
