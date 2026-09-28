# AI 配额动态窗口修订验收记录

日期：2026-09-28（Asia/Shanghai）。负责人修正替代旧的“四项必须同时显示”条件；历史验收记录保留。基线提交 `76c95dcecac24d11545c271c20ad9bba0aa7337b`；当前工作树指纹 `258cede7d8bb0e9901a6640f23712940c77750f72f251ec006ac9ad5720a7171`。任务 `A1`、`A3`、`QC-01` 为 verifying；原计划已验收点数仍为 10/76。

## 本次增量

- `QuotaWindowState` 分别表示有效窗口（允许真实 0%）、不适用、未报告、请求失败和 Provider 不可用。`QuotaItem.displayWindows` 将样本过期和重置到时的有效值标为 Stale，保留原百分比；缺字段不自动视为不适用。
- Overview、AI Coding、Menu Bar 共用 `QuotaRow` 和同一 `AppSnapshot`。不适用窗口不生成进度条或倒计时；状态未知和失败以文字显示。可见的共用行每 60 秒重新判断时间状态，未增加 Provider 轮询。
- `alertEligibleWindows` 只返回新鲜、适用、有真实数值且达到阈值的窗口。Phase A 未实现运行时配额通知或配额驱动的 Soul 文案，因而不会由缺失窗口产生提醒。
- Debug Mock 增加两家 Week-only、未报告、有效 0%、请求失败和过期场景；没有读取真实账户、修改认证或接入网络。当前规范、验收条件与状态页已修订；历史报告未改写。

## 实际验证

| 项目 | 结果 | 证据 |
|---|---|---|
| STATIC | PASS | `python3 scripts/verify-visual-assets.py` 退出 0；`.artifacts/visual-assets-check.json` |
| BUILD | PASS | `./scripts/verify.sh` 内 `./scripts/build.sh` 退出 0；`.artifacts/build.log` |
| UNIT | PASS | `./scripts/test.sh` 退出 0，12 个 XCTest、0 失败；`.artifacts/test.log` |
| LEDGER | PASS | `python3 scripts/verify_progress.py` 退出 0；`.artifacts/progress-verify.log` |
| MANUAL UI — 主窗口 | SCREENSHOT_REVIEW / OWNER_PENDING | 负责人截图显示 Codex 仅 Week 时只有 31% 的 Week 进度条和 `5h: Not applicable`；AI Coding 共用同一规则。负责人已确认 `Valid 0% quota`、`Quota request failed`、`Stale / offline` Fixture 状态正确。 |
| MANUAL UI — Menu Bar | PARTIAL / OWNER_PENDING | 负责人截图显示仅 Week 的 Codex、两窗口 Claude、来源和重置时间，并明确确认小图标、弹层背景及配额文字通过。随后新增 Disk/Battery 2×2 系统指标，更新后的完整弹层尚待复核。 |
| MANUAL UI — Cleaner 图标 / 品牌素材 | OWNER_CONFIRMED | 负责人已确认 Cleaner、六种 Soul 图片、Dock 图标及 Soul 标题品牌小图标。菜单栏 Draft 小尺寸已按当前效果获确认。 |
| PERFORMANCE | NOT_RUN | 未做 Release、无调试器场景的持续测量。 |
| LIVE PROVIDER | NOT_RUN | 本轮仅 Mock；账户能力、接口字段和跨客户端刷新未验证。 |

完整入口 `./scripts/verify.sh` 退出 0，详情见 `.artifacts/verification.json`。该命令生成的 `manual_ui: NOT_RUN` 专指脚本未自动执行人工界面检查；上表另记 Agent 主窗口冒烟观察，不把它算作负责人验收。所有本轮变更仍在本地工作树，尚未提交或推送。

## 待负责人验收

负责人已提交 Week-only 主窗口与菜单栏截图，确认有效 0%、失败与过期 Fixture，并确认菜单栏小图标、弹层背景和配额文字按当前效果通过。新增 Disk/Battery 系统卡片后，完整弹层仍需一次当前界面复核。
