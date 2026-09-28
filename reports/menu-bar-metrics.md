# 菜单栏系统指标与 README 补记

日期：2026-09-28（Asia/Shanghai）。基线提交 `76c95dcecac24d11545c271c20ad9bba0aa7337b`；当前源码指纹 `258cede7d8bb0e9901a6640f23712940c77750f72f251ec006ac9ad5720a7171`。本轮改动尚未提交或推送。

## 改动

- 菜单栏弹层从两张纵向指标卡改为 CPU、Memory used、Disk、Battery 的 2×2 排列。四项继续读取同一份 `AppSnapshot`；缺失的电池值仍通过 `MetricTile` 显示 `—` 和 `Unavailable`，不填造百分比。内存压力在卡片下单独说明。
- `docs/DESIGN.md` 已同步弹层顺序。README 增加项目介绍、当前阶段和概念主视觉。主视觉与下载目录原图 SHA-256 相同，文案明确其不是已实现功能或 App 截图。

## 验证

| 项目 | 状态 | 证据 |
|---|---|---|
| BUILD | PASS | `./scripts/verify.sh` 内 `./scripts/build.sh` 退出 0；`.artifacts/build.log` |
| UNIT | PASS | `./scripts/test.sh` 退出 0；12 项 XCTest，0 失败；`.artifacts/test.log` |
| STATIC | PASS | `python3 scripts/verify-visual-assets.py` 退出 0；`.artifacts/visual-assets-check.json` |
| RUNTIME MAIN WINDOW | PASS | `./scripts/run-mock.sh` 退出 0，新实例从被忽略的 `build-preview/` 启动；可访问性树显示 CPU 32%、Memory used 54%、Disk 67%、Battery 78%，以及两家 Mock 配额。 |
| MANUAL UI — NEW MENU GRID | NOT_RUN | 新菜单栏弹层尚无负责人截图或确认；先前确认只覆盖图标、背景和配额文字。 |
| PERFORMANCE | NOT_RUN | 未做 Release、无调试器持续测量。 |
| LIVE PROVIDER | NOT_RUN | 本轮仅 Mock 数据。 |

`./scripts/verify.sh` 初次退出 1，仅因账本中已完成任务引用旧源码指纹；doctor、build、unit、progress_tests、visual_assets 均退出 0。账本证据更新后复验结果见 `.artifacts/verification.json`。
