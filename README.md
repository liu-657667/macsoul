# MacSoul · 一体化开发启动包

**Your Mac knows what you're building.**

本包已合并：最新版 Family Harness、Day 1 SwiftUI 源码、Review 加固材料，以及早期 PRD 参考文档。
不用再下载或合并旧 ZIP。你截图里的 5 个审查文件已经位于 `review/`。

## 唯一开始入口

在本仓库根目录启动 Codex 或 Claude Code，发送：

```text
先读取 START-HERE.md，再读取 prompts/BOOTSTRAP.md。
按文档只执行 Phase A，保留现有改动。
结束时分别汇报 build、unit、manual UI、performance 的状态与证据。
```

## 这是什么 / 不是什么

这是**文档 + SwiftUI 起始源码 + AI 执行规则**的合并包，**不是已构建的 MacSoul.app**。
源码仍保留原始 Mock 实现，审查中发现的硬编码、周额度遗漏等，留给 Phase A 在你的 Mac 上修复并验证。
尚未提供 `.xcodeproj`、实际系统采样、真实配额接入或完成的构建/测试结果。Phase A 必须建立可重复构建入口。

## 文件导航

| 路径 | 用途 |
|---|---|
| `START-HERE.md` | 放文件、启动、验收及继续开发的说明 |
| `AGENTS.md` / `CLAUDE.md` | 共用工作规则与 Claude 导入入口 |
| `docs/PRD.md` / `docs/SCOPE.md` / `docs/DESIGN.md` | 产品概述、范围、界面契约 |
| `docs/ARCHITECTURE.md` / 专题文档 | 共享 Snapshot、Soul、网络与配额设计 |
| `docs/7-DAY-PLAN.md` | 旧七天基线，先加固再迁移，不自动重置进度 |
| `docs/PROGRESS-PROTOCOL.md` / `docs/STATUS.md` | 证据驱动汇报、追赶机制和当前状态 |
| `MacSoul/` | 原始 16 个 SwiftUI 起始源码文件 |
| `prompts/` | 唯一首次入口、每日、继续、审查与追赶任务 |
| `review/` | 完整 5 个审查文件，原样保留 |
| `templates/` | 原模型配置，仅作参考，不会在本包中自动启用 |
| `reference/` | 历史原文与概念效果图，不覆盖当前规范 |
| `scripts/check_bundle.py` | 只检查合并包完整性，不是 App 编译/测试 |
| `MANIFEST.md` / `BUNDLE-MANIFEST.json` | 文件说明及初始校验清单 |

## 产品边界

Menu Bar + 主窗口；System、Network、Dev、Codex/Claude 各自 **5h + Week**、本地 Soul。
AI 模块不做 Token、成本或 Agent Session。Cleaner 当前只允许只读扫描设计，Notch 不进入首次加固。
所有数字是演示数据，直到真实 provider 接入并验收。概念图不是已实现功能或安全保证。

## 当前验证

打包时检查了文件齐全、原始源码与审查文件保全、JSON/TOML 语法和 ZIP 完整性。
未在 macOS 编译/运行；UI、真实账户、性能、签名、公证都尚未执行。详见 `BUNDLE-CHECKS.json`。
