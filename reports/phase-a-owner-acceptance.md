# Phase A 负责人界面验收补记

日期：2026-09-28（Asia/Shanghai）。此记录补充 `reports/phase-a.md`，不改写当时的 NOT_RUN 事实。截图保留在对话中，未上传到公开仓库。

## 负责人确认

- 负责人查看了运行中的 Mock App 主窗口、AI Coding 与 macOS 菜单栏弹出层，确认 Codex 和 Claude Code 各有 5h、1 week 已用额度、可用的重置时间及 Mock 标记，并回复“其他的我看是通过的”。
- 首次查看时菜单栏有两个相同图标。进程检查发现同时运行了正常构建与先前干净目录验证留下的第二个 MacSoul 测试副本；源码仅声明一个 `MenuBarExtra`。负责人允许只退出测试副本。退出后只剩一个 MacSoul 进程，负责人回复“现在正常，确认通过”。
- 本次重复图标是测试副本并存造成的环境问题；未观察到单进程内重复创建菜单栏入口。
- 后续 Agent 复核时，按应用名称绑定界面工具又重新打开了旧测试副本；该副本已按负责人授权退出。随后只运行 `./scripts/verify.sh`，退出 0，进程复查仍只见正常构建一个 MacSoul 进程。避免再按名称打开旧测试副本。

## Agent 复核与范围

- App 可访问性树中，Overview 和 AI Coding 均显示两家四个额度窗口、相应进度、重置时间、Mock/Freshness/Source；System、Network、Dev 页面显示 Mock 状态及数据来源说明。
- 缺失额度窗口、过期样本和无电池等非默认 fixture 由 6 个 XCTest 覆盖；负责人此次没有逐个切换这些 fixture 进行视觉验收。它们不能据此宣称所有界面状态均经人工逐项确认。
- 此确认仅覆盖 Phase A Mock UI。真实性能与系统、网络、AI 配额 Provider 均为 NOT_RUN。

## 当前验证证据

- `./scripts/verify.sh`：doctor、build、unit、progress tests、ledger 均退出 0，详见本机 `.artifacts/verification.json` 及各日志。
- 负责人确认与 Agent 页面复核记录用于 A1/A3 的人工界面验收及 D1-02/D1-04 的 Mock 实现检查；`tasks.json` 为最终状态来源。
