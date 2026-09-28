# MacSoul

**Your Mac knows what you're building.**

macOS 原生 SwiftUI 开发者伴侣。当前仓库已经完成 Phase A 的工程、Mock 数据契约与任务账本实现；主窗口和 Menu Bar 的人工验收仍待完成。最初的合并包与历史审查材料保留在仓库中，不代表后续功能已经完成。

## 开发入口

先读 `START-HERE.md` 了解项目规则；继续开发时读 `prompts/CONTINUE.md` 和由 `tasks.json` 生成的 `docs/STATUS.md`。本机需安装 Xcode；工程最低部署目标为 macOS 13，当前实测环境见 `reports/phase-a.md`。

```sh
./scripts/doctor.sh
./scripts/verify.sh
```

`./scripts/verify.sh` 运行 doctor、Debug build、XCTest 和任务账本检查；日志、测试结果及验证摘要写入被 Git 忽略的 `.artifacts/`。首次克隆或源码变更后都需重新运行。可用 `open MacSoul.xcodeproj` 在 Xcode 中查看工程。

## 当前实现

仓库包含 `MacSoul.xcodeproj`、共享 scheme、App 和 XCTest target。主窗口与 Menu Bar 使用同一份 Mock Snapshot；Codex 和 Claude Code 各有 5h 与 Week 两个额度窗口，展示已用比例和可用的重置时间。当前没有真实系统采样、网络或 AI 配额接入。Mock、缺失及过期状态应按状态显示，不能当作实时数据。

Phase A 的本机 build/unit 曾通过；菜单栏弹出层与完整手工 UI 验收尚未完成，性能和真实 Provider 检查为 NOT_RUN。当前进度以 `docs/STATUS.md` 和 `tasks.json` 为准，既有报告记录其生成时的证据。

## 文件导航

| 路径 | 用途 |
|---|---|
| `START-HERE.md` | 放文件、启动、验收及继续开发的说明 |
| `AGENTS.md` / `CLAUDE.md` | 共用工作规则与 Claude 导入入口 |
| `docs/PRD.md` / `docs/SCOPE.md` / `docs/DESIGN.md` | 产品概述、范围、界面契约 |
| `docs/ARCHITECTURE.md` / 专题文档 | 共享 Snapshot、Soul、网络与配额设计 |
| `docs/7-DAY-PLAN.md` | 旧七天基线，先加固再迁移，不自动重置进度 |
| `docs/PROGRESS-PROTOCOL.md` / `docs/STATUS.md` | 证据驱动汇报、追赶机制和当前状态 |
| `MacSoul/` / `MacSoulTests/` / `MacSoul.xcodeproj` | App 源码、XCTest 与 Xcode 工程 |
| `prompts/` | 首次入口、继续、审查与追赶任务 |
| `review/` | 完整 5 个审查文件，原样保留 |
| `templates/` | 原模型配置，仅作参考，不会在本包中自动启用 |
| `reference/` | 历史原文与概念效果图，不覆盖当前规范 |
| `scripts/verify.sh` | 本机 build、unit 和账本的固定验证入口 |
| `scripts/check_bundle.py` | 仅检查原合并包完整性，不是 App 编译/测试 |
| `MANIFEST.md` / `BUNDLE-MANIFEST.json` | 文件说明及初始校验清单 |

## 产品边界

Menu Bar + 主窗口；System、Network、Dev、Codex/Claude 各自 **5h + Week**、本地 Soul。
AI 模块不做 Token、成本或 Agent Session。Cleaner 当前只允许只读扫描设计，Notch 不进入首次加固。
所有数字是演示数据，直到真实 provider 接入并验收。概念图不是已实现功能或安全保证。

## 验证状态

查看 `reports/phase-a.md` 中的实际命令、退出码和当次环境；它是历史证据，源码或工具链变化后须重跑。`BUNDLE-CHECKS.json` 仅验证最初合并包，不是 App 验收结果。

## License

MacSoul 有权授权的自有代码采用 [MIT License](LICENSE)，版权声明为 `Copyright (c) 2026 liu-657667`。第三方代码、依赖和素材保留各自的许可证、版权归属及必要声明，不因本项目采用 MIT 而被重新授权。`reference/` 中的历史输入和概念素材也不因根目录的 `LICENSE` 自动获得新的授权。
