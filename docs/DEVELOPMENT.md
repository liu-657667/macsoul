# MacSoul 开发指南

[项目首页](../README.md) · [English overview](../README.en.md)

本页整理开发、验证和 Harness 入口，不是新的产品规范，也不改变原任务范围。产品介绍见 README；当前状态以 `tasks.json` 和生成的 `docs/STATUS.md` 为准。

## 1. 先确认分支与任务

```bash
git status --short --branch
git log -1 --oneline
```

阅读 [AGENTS.md](../AGENTS.md)、[STATUS.md](STATUS.md)、[INTEGRATION-NOTES.md](INTEGRATION-NOTES.md) 和 [CONTINUE.md](../prompts/CONTINUE.md)。只在确有未完成的 Phase A 工作时再读 [BOOTSTRAP.md](../prompts/BOOTSTRAP.md)，不要把已归档的首次导入说明当成重新初始化指令。

现有本地改动、未完成任务和验收记录必须保留。不要仅因 README、模型或目录整理发生变化，就重置工程或重建 Harness。

## 2. 工具链与运行

需要完整 Xcode、可运行项目校验脚本的 Python 3 和 Git。项目最低部署目标为 macOS 13，实际兼容性以验证记录为准。Codex / Claude Code 是可选开发辅助工具，不是体验 Mock App 的必需依赖。

```bash
./scripts/doctor.sh
./scripts/verify.sh
./scripts/run-mock.sh
```

- `doctor.sh` 输出本机工具链和工程信息，不自动安装工具。
- `verify.sh` 运行环境检查、Debug build、XCTest、进度脚本测试、资源校验与账本检查。
- `run-mock.sh` 会先检查是否已有 MacSoul 实例；请正常退出旧实例后再运行。脚本构建后把 App 复制到被忽略的可见 `build-preview/` 目录并启动，最终输出实际 App 路径。直接从隐藏的 `.artifacts/DerivedData` 启动曾让 Dock 显示通用图标，因此预览请使用此入口。
- 可通过 `open MacSoul.xcodeproj` 在 Xcode 中打开工程。

不要把“构建脚本退出 0”当作人工 UI、真实性或性能验收全部通过。单次构建也不能证明所有系统版本都兼容。

## 3. 验证与证据

日志、测试结果和验证摘要保存在被 Git 忽略的 `.artifacts/`。例如 `.artifacts/verification.json` 记录命令、退出码、Git revision、工作树指纹和工具链信息。克隆后本地没有这份文件是正常的；运行验证生成自己的结果，不要依赖其他机器的绝对路径。

| 检查 | 证明什么 | 不证明什么 |
|---|---|---|
| Build | 对应代码与工具链完成构建 | 实际界面、实时数据和性能均合格 |
| Unit / progress / assets | 已覆盖用例与静态规则通过 | 所有交互或外部服务都经过验证 |
| Manual UI | 人工检查的具体画面/交互 | 未检查的场景也通过 |
| Live data | 指定数据源的实际接入被验证 | 其他 Provider 或其他账户全部可用 |
| Performance | 记录条件下的具体测量结果 | 所有设备、场景都达到目标 |

未运行时保留 `NOT_RUN`，未测量时保留 `NOT_MEASURED`。历史证据保留原结论；相关实现变化后重新验证，不篡改旧结果。

已入库的阶段记录包括 [视觉收尾报告](../reports/phase-a-visual-closeout-2026-09-28.md) 与 [仓库卫生报告](../reports/repository-hygiene-2026-09-28.md)。这些只证明各自对应的阶段；本次文档变更的检查结果以本次实际运行记录为准。

[GitHub Actions](https://github.com/liu-657667/macsoul/actions) 的结果以具体提交的工作流记录为准，不在 README 手写永久为绿的 CI 或测试数量。

## 4. 当前与历史材料

| 入口 | 用途 |
|---|---|
| `docs/PRD.md`、`docs/SCOPE.md`、`docs/DESIGN.md` | 产品、范围与界面契约 |
| `docs/ARCHITECTURE.md` 与模块文档 | 共享快照、采样、Soul 和 Provider 设计 |
| `tasks.json` | 当前任务账本，保留原计划及验收证据 |
| `docs/STATUS.md` | 由账本生成的状态，不手动维护第二套进度 |
| `docs/PROGRESS-PROTOCOL.md` | 汇报、阻塞与追赶规则 |
| `prompts/`、`review/`、`reports/` | 任务入口、审查与阶段记录 |
| `MacSoul/`、`MacSoulTests/`、`MacSoul.xcodeproj/` | 源码、测试及共享工程 |
| `assets-source/` 与资源目录 | 原稿、清单及 App 运行时资源 |
| `docs/archive/bootstrap/` | 一次性启动包与旧入口，仅供历史参考 |
| `reference/`、`templates/` | 历史材料与配置示例，不自动授权执行 |

`docs/7-DAY-PLAN.md` 保留原始基线，当前状态从账本读取。旧 `check_bundle.py --hashes` 核对的是原始启动包；开发后文件变化或归档导致不一致时，应说明原因，而不是把历史清单改写成当前工程的“通过证明”。正式验证应使用当前维护的工程检查入口。

资源清单检查仍与 `assets-source/` 相关联。不能为了减少仓库文件数直接忽略或删除整个目录。

## 5. 文档、真实能力与发布保持一致

README 面向体验者。PRD 和任务账本面向实现者。更新 README 时：

1. 只把当前分支已实现、且有相应证据的能力写成可用；未合并的分支工作不能先写成主分支功能。
2. Mock、真实但未验收、已验收和未来计划分开表达。
3. 额度按实际窗口展示，不根据套餐名字硬编码；0%、未报告、明确不适用、失败和过期保持区别。
4. 用真实运行截图展示当前应用，并标记截图的数据模式；概念图只能作为概念图。
5. 保留第三方许可和资源来源说明，不在文档重写中丢掉原声明。
6. 文档工作不要打断另一个正在写代码的 Agent。确需并行时使用隔离的工作目录/分支，合并后检查链接和当前事实。

README 发布新能力之前，应检查对应代码是否已进入目标分支。开发日志不会自动变成产品公告。

## 6. 安全与提交

不要提交凭据、原始敏感日志、个人配置或构建产物。Git 忽略规则不是完整的泄露检查，提交前仍需检查暂存内容。

提交、推送、打 tag 和 Release 是不同动作，按负责人授权执行。这个开发指南不赋予自动发布权限，也不会在 Agent 会话结束后自动运行每日任务。
