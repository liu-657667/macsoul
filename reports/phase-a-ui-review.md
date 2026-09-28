# Phase A UI 修订与当前验收

日期：2026-09-28（Asia/Shanghai）。本报告记录当前 Mock App 的增量 UI 修订；历史验收记录保留在 `reports/phase-a-owner-acceptance.md`。负责人已将本轮总体视觉验收定为 **PARTIAL**。

当前自动证据：`./scripts/verify.sh` 退出 0，UTC 检查时间 `2026-09-28T14:28:02Z`；Git revision `36627134446cd8895d8b17397ce3ae848418ddd7`，工作树指纹 `e4fa9b0e21802c45b1dc4136570710d563c49960fb5f097f9ba84c50158dbbbe`。本机 macOS 27.0 / Xcode 27.0 (27A266a)。工作树仍有未提交修改，以上 revision 不能单独代表本轮源码。

## 已修改

- 菜单栏弹层使用不透壁纸的语义窗口背景和语义文字色；CPU、内存、磁盘、电池以紧凑 2×2 网格呈现。一个 `MOCK DATA` 标记说明当前数据属性。
- Overview 的标题与工具栏分离，两列内容从顶部对齐；系统指标使用紧凑 2×2 布局。Settings 改为顶部对齐的分组界面，区分当前构建能力和开发预览场景。
- Overview 与菜单栏显示配额摘要：有效适用窗口显示已用百分比和短重置提示；明确不适用的窗口不占摘要行。AI Coding 详情保留来源、完整时间、Fresh 和不适用原因；未报告、请求失败、不可用及过期仍在摘要中明确显示。重置提示使用传入的 `TimelineView` 时钟；倒计时结束后显示“等待刷新”，不会自行把已用量置零。
- Settings 增加仅作用于 MacSoul 主窗口和菜单栏内容的外观选择（跟随 macOS、浅色、深色），以及英语／简体中文切换。选择不会改变系统外观、Mock Snapshot 或配额状态。macOS 自带菜单栏和系统控件的语言由系统决定。负责人在深色中文截图中发现弹层仍为浅色；修复后将选定色系显式传给独立的 Menu Bar 场景，并按该色系解析弹层背景。系统指标行也保留百分比的完整宽度，让指标名称先适度缩小。
- Cleaner 侧栏及 Overview 标题改用负责人提供的 Phosphor 扫把 SVG。它与 Phosphor 官方原件的 SHA-256 一致，使用独立 `MacSoulCleaner.xcassets`，不覆盖既有品牌资源；完整原许可写入 `ThirdPartyNotices.txt` 并进入 App bundle。负责人截图可见侧栏扫把。
- 负责人随后发现“深色→跟随 macOS／浅色”出现混色与空白，截图保存在 `.artifacts/ui/appearance-follow-mixed-user.png`、`.artifacts/ui/appearance-light-blank-user.png`、`.artifacts/ui/appearance-dark-blank-user.png`。前两版局部 SwiftUI / 窗口外观桥接均未通过人工复核。当前候选按 Apple AppKit 的应用级 `NSApplication.appearance` 设置 MacSoul 外观，`nil` 代表跟随系统；不修改 macOS 全局设置。负责人在“深色→跟随 macOS（系统浅色）”复核后回复“现在正常了”。这是该切换故障的人工确认，不代表全部 UI 验收通过。
- 负责人截图显示总览与菜单栏四项紧凑系统指标的首字左上笔画缺失。`MetricTile` 之前即使无内边距仍把紧凑内容裁进 12 点圆角；现在只对非紧凑卡片应用圆角裁切。修复版重启后，负责人确认两处文字都完整。原问题截图保存在 `.artifacts/ui/metric-label-clipping-overview-user.png` 与 `.artifacts/ui/metric-label-clipping-menu-user.png`。

## 菜单栏图标

当前资源是 `MacSoulMenuTemplateDraft`，资源目录含 18 px @1× 与 36 px @2× 图像，逻辑尺寸为 18 pt。`Contents.json` 设置 `template-rendering-intent: template`，预览也使用 `.renderingMode(.template)`；`MenuBarExtra` 引用该资源名。它仍是 **DRAFT**，没有把小尺寸图案的人工观感标为通过。

## 验证和人工反馈

| 项目 | 结果 | 证据与限制 |
|---|---|---|
| doctor | PASS | `./scripts/verify.sh` 内执行；`.artifacts/doctor.log` |
| build | PASS | `./scripts/build.sh`，退出 0；`.artifacts/build.log` |
| unit | PASS | `./scripts/test.sh`，17 个 XCTest，0 失败；`.artifacts/test.log`。覆盖短重置提示、应用外观映射、中英摘要文字、浅/深语义色对比度和扫把资源加载。 |
| 账本与资源检查 | PASS | `python3 scripts/test_progress.py`、`python3 scripts/verify-visual-assets.py`；见 `.artifacts/verification.json`。 |
| manual UI | PARTIAL | 负责人提供浅色 Week-only 的 Settings、Overview、菜单栏截图，保存在本机 `.artifacts/ui/`，未上传 Git。Overview 与菜单栏的 Codex Week 均为 31%，无虚构 5h 行；Claude Code 显示 5h 81% 与 Week 47%；正常 Soul 图案、四项系统指标、短重置提示可见。截图也显示复杂壁纸下弹层正文背景为实色。 |
| 深色／中文实际界面 | PARTIAL | 负责人先前确认深色中文菜单栏弹层可读，后续切换外观发现主窗口混色或空白。应用级外观修复后，负责人针对深色→跟随系统（系统浅色）的复核回复“现在正常了”。当前候选没有新的完整截图；其余视觉与交互项目仍待复核。 |
| 紧凑指标文字 | PASS（本项） | 总览和菜单栏原问题截图显示首字左上笔画被圆角裁切；修复版构建并重启后，负责人回复“两处文字都完整”。新截图未提供，本项人工确认不替代全部视觉验收。 |
| Dock 与其余五种 Soul | PENDING | 依负责人本轮纠正，尚待人工验收。 |
| performance | NOT_RUN | 未做 Release、无调试器的 CPU／内存测量。 |
| live provider | NOT_RUN | 仍为本地 Mock；无真实系统、网络或账户采集。 |

本轮浅色 Week-only 截图路径：`.artifacts/ui/settings-week-only-light.png`、`.artifacts/ui/overview-week-only-light.png`、`.artifacts/ui/menu-week-only-light.png`。深色中文问题与修复截图路径：`.artifacts/ui/overview-default-dark-zh-user.png`、`.artifacts/ui/menu-default-light-despite-dark-zh-user.png`、`.artifacts/ui/menu-default-dark-zh-fixed-owner.png`。这组三张是在默认双窗口场景拍摄；旧进程运行一段时间后配额显示“已过期”，保留最后的已用量而未伪造 0%；修复版重启后显示新鲜的短重置提示。这些静态截图不能证明所有交互已通过。

## 当前边界与下一项

Phase A 停在人工验收。当前候选经 `./scripts/run-mock.sh` 退出 0，位于 `build-preview/MacSoul.TSbfeJ/MacSoul.app`；可访问性树看到中文菜单栏的四项指标和动态配额。自动界面截图出现透视变形，未将其作为视觉证据；外观切换与紧凑指标字形已由负责人在交互中确认正常。Dock、其余五种 Soul 图案和完整交互仍待人工验收。动态窗口语义和 Mock 范围保持不变；不进入真实 Provider、Notch 或 Cleaner 删除功能。
