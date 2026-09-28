# Codex / Claude Code：MacSoul Harness 加固执行提示

> 2026-09-28 负责人修正：下文历史“四窗口必显”措辞已由 `AGENTS.md`、`docs/DESIGN.md` 和 `docs/AI-QUOTA.md` 的动态窗口规则取代。保留原审查文字作为历史记录，不再据此要求虚构 5h。

你正在一个已有 MacSoul 仓库内工作。本次先改造执行可靠性，不重新设计产品，也不一次做完七天功能。

## 读取

读取当前实际生效的项目指令、review/AUDIT.md、当前状态/计划、Day 1 设计与源码。
若此文件不在 review/ 中，基于实际文件位置解析路径。旧文档和本审查有冲突时，把明确冲突与最小修正方案列出；不得清空已有进度。
遵守当前会话更高优先级指令、用户授权和工具权限。

## 开始前

1. 检查 git status 和当前 branch；不要覆盖、回滚或删除用户未提交改动。不要 git reset --hard。
2. 报告实际 OS、Xcode/Swift、Codex/Claude 版本和模型信息；不可观测字段用 UNKNOWN。
3. 当前环境不能构建 macOS App 时，静态检查可继续，但 build/test/UI/performance 不能标 PASS。
4. 盘点现有工程与脚本。已经存在的内容增量修正，不创建第二套 AppStore 或第二个“权威 PRD”。
5. 输出不超过 8 行的实施计划；只有真实外部授权或无法解析的产品冲突才暂停询问。

## Phase A — 本次必须完成的最小加固

A1. 合并规范与入口
- docs/SCOPE.md + docs/DESIGN.md 维护单一产品契约。
- 主窗口和 Menu Bar 均显示 Codex、Claude Code 的 5h + Week 已用百分比及可用的 reset 信息。
- 历史 Day 1 设计指向当前设计，避免保留互相冲突的规范。
- 不自动做 Notch、Token/费用/Agent Session、账号体系。
- CLAUDE.md 使用已验证客户端支持的明确导入方式共享 AGENTS.md，并验证实际加载。

A2. 可重复构建
- 优先复用工程；缺工程则创建原生 macOS 工程、共享 scheme 和 test target。
- 明确最低 macOS 和实际 Xcode 版本，不能声称未测试的版本兼容。
- 创建 doctor/build/test/verify 固定入口，真实保存退出码和证据。
- 不自动安装升级全局工具，不改全局 Codex/Claude 配置。
- 构建日志放在 gitignored 的本地证据目录；脱敏摘要才进入报告。

A3. 修正 Mock 契约
- View 不直接依赖 MockStore 类型；一个组合入口切换 mock/live provider。
- 所有数字文本/进度条均从相同 Snapshot 计算，移除固定 96% 等混用。
- Quota 每个窗口独立可缺失、reset 用 Date、稳定 ID、清楚区分 fresh/stale/unavailable 和 mock/live。
- 当前仅用 fixture，不连接真实 Provider。
- fixture 至少覆盖 healthy、CPU critical/recovery、memory pressure、quota 95%、单窗口缺失、stale/offline、无电池。
- 纯逻辑单测使用可注入 Clock，不靠真实 sleep 等 30 秒。
- App/UI 必须明确 Mock 状态，不能把图形展示当作真实采样已实现。

A4. 结构化任务和证据
- tasks.json 为任务状态唯一写入源，保留旧完成记录，迁移时不能重新置零。
- 不直接把 review/tasks.example.json 当成已认可的新七天计划；它只是 schema 示例。
- 任务含 ID、依赖、优先级、原始/当前计划、范围、验收、证据、状态。
- STATUS.md 从账本生成；增加 verify-progress 检查脚本及正反例测试。
- done 必须有当前 revision/工作树指纹、命令/退出码、验收项对应证据；人工 UI 验收独立确认。
- 改动相关文件后，失效的旧证据不能继续证明本次通过。
- 任务延期不能删除；记录原因、原始点数、批准的范围变更；报告原计划与调整后计划两种完成率。
- 先实现小而清楚的本地 JSON + 脚本；不要引入服务端、数据库、Web 管理界面或复杂框架。

## 执行与权限

默认一个 Agent 写代码；reviewer 只读。reporter 输出摘要，由脚本/主 Agent 合并，不宣称自然语言限制具有文件系统强制力。
测试 Agent 可顺序工作；必须并行写时用独立 worktree 和明确文件范围，合并后重跑集成测试。
不要为写日报启动多名 Agent。不得自己给完成率打分后跳过验收。
不要读取凭据、上传日志/项目、安装未经审查的 skill、删除开发缓存或真实用户数据。
模型选择保留当前可用的角色策略；模型切换按已验证工具能力，不编造 model ID/参数。
不通过隐藏 failed/blocked、删测试或加 Mock 回退来制造全部完成。

## 本次停止条件

Phase A完成并验证后停止，不执行真实配额/网络接入、清理器或后续产品功能。
若 Phase A 被环境阻塞：完成可独立做的部分，给出阻塞证据、已做/未做列表和下一条可执行命令；不要标全通过。

## 最终汇报格式

- 本次目标与完成的任务 ID。
- 修改文件与关键差异。
- 实际运行的命令、退出码、revision/工作树指纹和证据路径。
- build / unit / manual UI / performance 的分别状态，未运行明确 NOT_RUN。
- 未完成任务、原因、依赖和下次第一项。
- 是否改动 scope/优先级/基线，需负责人决定什么。
- 实际可见模型/角色信息；未知标 UNKNOWN。
- 不承诺会在退出会话后自动继续执行或明日主动汇报。
