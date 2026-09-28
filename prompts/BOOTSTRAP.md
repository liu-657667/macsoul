# MacSoul 一体包 — 首次执行

> 此页保留为未完成 Phase A 项目的首次执行说明。当前仓库已有 Xcode 工程与任务账本；先看 `docs/STATUS.md`，不要将以下初始化措辞解释为进度回退。

只执行已有 Review 的 Phase A，不一次写完产品。

## 读取顺序
1. `AGENTS.md`
2. `docs/STATUS.md`
3. `docs/INTEGRATION-NOTES.md`
4. `docs/SCOPE.md` 和 `docs/DESIGN.md`
5. `review/AUDIT.md`
6. `review/CODEX-HARDENING-PROMPT.md`
7. 任务需要的 `MacSoul/` 源码与 `docs/ARCHITECTURE.md`

## 开始
- 检查当前目录、git status、工程是否已有改动，不初始化第二套源码或覆盖用户进度。
- 可运行 `python3 scripts/check_bundle.py` 检查文件，**这不是 App 验收**。
- 报告实际 macOS/Xcode/Swift/客户端版本；不可观测字段写 UNKNOWN。
- 包中没有已验收的 Xcode 工程。优先复用本地已有工程，否则按 Phase A 创建工程/共享 scheme/测试 target。
- 当前所有 Swift 文件是原始 Mock 起点，Review 里的源码问题尚未被打包步骤修复。

## 本次交付
遵循 `review/CODEX-HARDENING-PROMPT.md` 完成 A1–A4：
- 统一规范，双 surface 按实际适用情况动态展示 Codex / Claude Code 的 5h / Week；仅有 Week 时不补假 5h；
- 可重复 build/test/verify 与真实证据；
- Mock/真实数据共用契约，消除硬编码，覆盖缺失/过期等场景；
- 结构化任务账本和进度校验，保留旧基线与未完成项。

本包只做了入口/目录加固，不要把这些打包修订计作 App 任务完成。
`review/tasks.example.json` 不是完整计划；不得直接复制后宣布迁移完成。

## 停止条件
A1–A4 完成并验证后停止。环境阻塞则记录事实，继续可独立部分后给出下一条可执行命令。
不接真实配额/IP，不做 Cleaner 删除、不做 Notch、不发布远程仓库。
最后用中文汇报：修改、已验收/未验收、build/unit/manual UI/performance、证据、阻塞、下一步。
