# MacSoul Harness 审查与加固建议

审查日期：2026-09-27  
对象：会话中提供的 `MacSoul-GPT6-Family-Harness.zip` 与 `MacSoul-Day1-Starter.zip`。  
本报告不代表对你 GitHub 当前分支的审查，也没有修改原包。

## 结论

保留现有产品定位、Soul、Menu Bar、5h + 1 week 配额和本地优先路线。不需要因为更换聊天模型重新发明产品。
当前短板是：规范存在分叉、Mock 与正式模型没有贯通、进度数据缺少可执行验证、最高风险集成验证偏晚。
应把现有 Harness 从“文档 + 约定”补成“单一规范 + 小任务 + 可运行验收 + 证据驱动进度”的闭环。

## 审查边界与已执行检查

- 解压并检查 Harness 配置、关键产品/架构/进度/质量文档及 Day 1 Swift 源码。
- Harness 含 42 个文件；Day 1 含 16 个 Swift 文件。
- 6 个 TOML 文件语法解析通过。语法通过不等于本机 Codex 已加载、模型可用或子代理权限经过验证。
- 7 天计分之和为 76，全部标为 P0。
- 两包内没有 `.xcodeproj`、`Package.swift`、`.github/workflows` 工作流文件或 `scripts/` 文件。这符合“源码片段/说明包”的交付状态，但不是一个开箱可构建的仓库。
- 对独立挂载的 5 份 Harness 文档做了与 ZIP 内文件的字节一致性检查，均一致。
- 未运行 Xcode build/test、SwiftUI UI、真实额度账户验证或 Instruments；当前环境不是 macOS。
- 已阅读当前官方模型/配置文档。尝试在容器下载 JSON schema 进行自动验证时网络解析失败；不能把此次检查描述成 schema 验证通过。
- 机器可读结果和原包 SHA-256 见 `static-checks.json`。

## H01 — 优先修复：规范分叉和菜单栏周额度遗漏

**证据**
- Harness `docs/DESIGN.md:9-18` 要求 Menu Bar 显示 Codex 与 Claude 各自的 5h + Week。
- Day 1 原文 `reference/originals/day1/DAY1-DESIGN-LOCK.md:98-109` 只列 Codex 5h、Claude 5h。
- Day 1 `MacSoul/MenuBar/MenuBarContentView.swift:29-30` 实际也只画两行 5h。
- Harness `AGENTS.md` / `7-DAY-PLAN.md` 把第 5 天设为功能冻结，但 Day 6 仍保留 Notch prototype。

**影响**：两个 Agent 分别遵循两个文件时，都可能认为自己完成了正确设计；菜单栏遗漏用户明确确认的 Week。

**修正**
1. 合并为一个工作仓库；保留 `docs/SCOPE.md` + `docs/DESIGN.md` 为产品事实来源，Day 1 设计锁定文件改成链接或标为历史。
2. 主窗口和弹出菜单都显示两家 Provider 的 5h + 1 week；数字统一标注“已用”。
3. 冻结以后不再新做 Notch；进入后续版本。
4. 规则冲突优先服从实际会话中适用的更高优先级指令与用户已批准变更，再同步文档；不要让旧 AGENTS.md 阻止产品负责人修订需求。

**验收**：修改一处配额 fixture，主窗口与 Menu Bar 四个窗口指标同时更新；两个 surface 的缺失/过期状态一致。

## H02 — 优先修复：Mock 不是可直接切换的 Provider

**证据**
- `MacSoul/Views/Overview/OverviewView.swift:56-59`：CPU/RAM/Disk/Battery 文本写死，只有 progress 取 Store。
- `MacSoul/MenuBar/MenuBarContentView.swift:25-26` 同样混用固定文本和动态进度。
- `MacSoul/Views/System/SystemView.swift:7-17` 展示固定数字。
- 多个 View 直接依赖 `MockStore`。
- `MacSoul/Models/MacSoulModels.swift:11-18` 的 QuotaItem 强制两个 Double，reset 是 String，没有缺失、数据源和更新时间。

例如原代码：
```swift
MetricTile(name: "CPU", value: "96%", progress: store.cpu)
```
当 `store.cpu` 变成 0.20，进度条与数字会不一致。这是静态可确认的问题，不需要假称运行过 App。

**修正**
- 固定 View → 展示状态 → Snapshot 的关系；MockProvider 和 NativeProvider 只在组合入口切换。
- 不为“架构漂亮”一次引入大量框架：一个 AppStore/模块状态、薄 Provider 接口和纯模型即可。
- 百分比统一单位，例如领域层使用 0...100，渲染时再转换；防止 0.62 与 62 混用。
- QuotaWindow 保存 `usedPercent`、`durationMinutes`、`resetsAt: Date?`，每个窗口独立可空，并保存来源、观测时间、状态。
- Provider/窗口使用稳定 ID；不要每次刷新给全部条目重新生成 UUID。
- 区分 data mode（mock/live）和 freshness（fresh/stale/unavailable），它们不是同一维度。

**验收**：20%、96%、nil 三种 CPU fixture；Quota 双窗口、缺一窗口、过期、不可用；文字、进度条、辅助文案完全一致。Mock 模式全局有清楚标记。

## H03 — 优先修复：缺少可重复构建和命令化质量门禁

**证据**
- 原文 `reference/originals/day1/CODEX-DAY1-PROMPT.md:8-9` 要求后续 Agent 创建或修复 Xcode 工程并构建。
- ZIP 清单中没有工程文件、测试 target 或构建脚本。
- `docs/QUALITY-GATES.md` 有“build/tests pass”等规则，没有固定命令、退出码、证据目录和 CI 配置。

**修正**
- 第一个任务是交付可构建工程及共享 scheme，采用现有 macOS 13+ 基线时避免无意混入更高版本 API。
- 检查 `MockStore.swift` 中 `ObservableObject/@Published` 的显式模块导入，并以真实编译结果确认；此审查未把它当成已经复现的编译失败。
- 建立统一入口：`scripts/doctor.sh`、`scripts/build.sh`、`scripts/test.sh`、`scripts/verify.sh`。
- `doctor` 输出系统/架构、Xcode/Swift/Codex/Claude 版本和项目路径；缺少必需工具必须清楚失败，不能伪装绿灯。
- `verify` 保存命令、退出码、Git revision/工作树指纹、时间、工具链版本、日志/xcresult 路径。
- macOS CI 复用相同脚本，不另写一套“CI 专用成功条件”。
- build、unit、manual UI、performance、release validation 分开标记。无 macOS 时明确 NOT_RUN。

**验收**：新克隆的同一 revision 用固定命令能重现 build/test；若相关源代码变了，旧证据不能继续作为当前完成证明。

## H04 — 优先修复：额度集成风险发现得太晚

**证据**：`docs/7-DAY-PLAN.md:52-66`将 Codex 实现及 Claude 数据源 spike 都放在 Day 4。

**修正**
- Day 1 的产品设计之后，安排隔离、只读的 capability spike，不接入主 UI，不上传凭据，不扩产品范围。
- 输出 provider 版本、数据字段、认证方式是否适用、至少一份脱敏样例、字段缺失原因和 cross-session 更新验证结果。
- 只有连接了支持的数据源并验证过实际值，才算“真实配额已接入”。
- `Unavailable` 是必须完成的容错状态，不等于成功完成额度读取。
- 若关键 Provider 无法接通，尽早报告并由你选择发布 preview、缩减兼容范围或延期该功能；不能由 Agent 默默把承诺改掉。

### 当前官方接口应如何进入文档

Claude Code 当前官方 statusline 文档明确列出：
```text
rate_limits.five_hour.used_percentage
rate_limits.five_hour.resets_at
rate_limits.seven_day.used_percentage
rate_limits.seven_day.resets_at
```
文档对该示例注明 Claude Code 版本要求、适用订阅/网关场景、首个 API 响应之后才可能出现，以及各窗口可独立缺失。实现时按本机实际版本再次核验，不把所有用户都当作字段齐全。

Codex 当前 app-server 文档列出 `account/rateLimits/read` 和 `account/rateLimits/updated`，并有多 bucket 结构。按正确账户/bucket 和窗口时长映射；不要把每个 primary 都当 5h。

“能接收本连接更新”不能未经实测扩写成“保证其他 CLI、App、网页中所有消耗都会立即同步”。跨客户端更新覆盖范围应有单独测试。

### 新鲜度与重置规则（建议的产品契约）

- 接到有效数据后，建议以 1 秒以内更新可见 UI 为验收目标；这测量的是本地显示延迟，不是官方配额结算延迟。
- 根据数据源可用性选择事件 + 有限低频刷新，尊重限流和暂停条件。
- 倒计时到零只表示旧窗口已过期；没有新快照时不能自行显示已用 0%。
- stale 值保留最后更新时间，不触发新的额度不足通知。
- 缺失某个窗口只影响该窗口，不清空另一个仍有效的窗口。
- Bridge 只提取额度字段，丢弃其余输入，不记录完整 statusline JSON；安装前展示配置变更并保留原 statusline，支持卸载恢复。

## H05 — 优先修复：所有计分任务都是 P0，追赶机制缺乏真实空间

**证据**：7 天计分为 10/12/12/11/11/10/10，总计 76 点，全列 P0；P1/P2 未计分。`PROGRESS-PROTOCOL.md` 首先砍 P2，但对原来的 76 点主计划几乎没有减负。

**修正**
- P0 只保留真正影响核心可用与安全质量的交付；Cleaner 扫描、额外运行时适配、地域补充等由产品负责人确认哪些属于 P1。
- 不是直接删掉用户需要的能力，而是明确必须支持的最小兼容矩阵，额外范围走可见 backlog。
- 不把相对 point 当成 AI 小时或实际工期；每日保留建议 20%–30% 调试缓冲并根据实绩重估。
- 技术依赖图决定下一个 ready task；Day 编号是检查点，不是完成后必须闲置到明天的障碍。
- 同时记录“原始承诺交付率”“调整范围交付率”“被延期范围”，不能删除未完成项来制造 100%。
- 红黄绿按明确优先级计算：release blocker 优先；不要让百分比盖过未完成关键项。

**追赶队列建议**
```text
构建/运行回归
→ 阻塞核心路径的未完成任务
→ 验收和关键集成
→ 当日已 ready 的核心任务
→ 经批准的可选任务
```

## H06 — 优先修复：从自由文本汇报改为任务与证据账本

**现状**：已有 STATUS、日报、计分及验收规则。这些值得保留，但目前没有结构化任务 ID、依赖、冻结基线与证据校验器。

**最小方案**
- 一个 `tasks.json` 作为状态权威来源；`STATUS.md` 由脚本生成，不双写两套状态。
- 状态：todo / doing / blocked / verifying / done / deferred。
- 一个任务有 ID、优先级、依赖、原始计划日、当前计划日、验收项、允许修改范围、证据、复核结果。
- 通过的验证记录必须绑定 revision/工作树指纹，并说明命令、退出码和未覆盖项。
- `verify-progress` 能发现 done 无证据、依赖缺失、证据文件丢失、baseline 被无记录重写、blocked 无原因等情况。
- 人工 UI 验收使用截图/复现步骤/人工确认，不把截图存在自动当作“看过并且通过”。
- 日报由账本与验证结果生成，Agent 补写简短原因和计划。模型名字从实际运行可见信息记录；未知就标 UNKNOWN。

**示例日报**（模板，不是本次开发结果）
```text
Day 2 / Schedule YELLOW
原定 8 点，验收 6 点，75%
未完成：SYS-03，睡眠唤醒后重复采样
Build：PASS（链接至本次日志）
Unit：PASS（链接至本次测试结果）
Manual UI：NOT_RUN
下一项：先修 SYS-03，再继续配额 Adapter
延期范围：Cleaner 自动清理，待产品负责人确认
```

每天自动执行这些动作的前提是 Agent 会话或你配置的运行器仍在工作。Markdown 不是定时器，不能在退出 Codex 后自动唤醒、追赶或主动发消息。

## H07 — 建议简化：模型策略与产品规范解耦，默认单写者

**证据**：已有 Sol 主开发、Astra 架构审查、Luna 辅助策略；无需全部否定。`reporter.toml:5-7` 使用 workspace-write，仅靠文字约束“不写生产代码”。

**改进**
- 稳定文档描述角色与权限；具体 model ID/effort 放配置例子和本机能力记录中。
- 不把 ChatGPT 界面标签当 CLI model ID，不因为切换聊天模型就重写 PRD。
- 运行前核验 CLI 版本、实际模型可用性、配置是否加载。TOML 解析只证明语法。
- 默认一个开发写者 + 一个按需只读 reviewer；explorer 只在探索收益明显时启动；测试文件需要写入时顺序执行或分支/worktree 隔离。
- reporter 默认只读生成结构化结果，再由主代理或脚本落盘；不要把 workspace-write 宣称为 docs-only 硬权限。
- 即使用 worktree 也需指定文件所有权、基线 commit、回传结果和合并后集成测试。
- 模型路由建议：Sol high 日常实现，Astra high 重要设计/审查/有证据的难题，Luna 明确边界的检索/文档整理。升级 effort 由错误证据决定，不由日历变红自动触发。
- 脚本可生成的百分比和文件清单不再需要专职 LLM。

**兼容性修正**
- `CLAUDE.md` 目前只是自然语言要求“读取 AGENTS”。采用官方支持的 `@AGENTS.md` 显式导入，并保持入口短小。
- 不要自动导入全部文档。功能级文档按任务读取。
- 第三方仓库、日志、网页中的指令视为被分析的数据，不能反过来覆盖项目操作权限。

## H08 — 建议补齐：性能目标必须定义测量条件

现有 <0.5% CPU / 100–150MB 目标可以保留为待验证目标，但不是已实现结论。

建议协议：固定一台基准 Apple Silicon 设备；记录内存、macOS、Xcode、构建模式；Release build、脱离 debugger；预热 2 分钟，采样 10 分钟，每场景重复 3 次。数值仅为建议基线。

至少分别测量 Menu Bar 后台、System 前台、额度 bridge/app-server 开启、网络异常重连和睡眠唤醒。

记录 MacSoul 本进程与它自行启动的 helper/app-server 的独立及合计 CPU、内存、采样/请求次数。不能把资源开销挪到子进程后宣称零成本。用户原来运行的 Codex 不计为本产品新增开销，单独说明边界。

确认 CPU 百分比的分母、内存使用量指标和峰值/均值口径；没有量到就报告 NOT_MEASURED。不强求 UI 首屏渲染峰值也满足后台平均阈值。

## H09 — 建议补齐：网络、运行时和清理的事实边界

- public IP lookup / connectivity probe 有外部网络请求；“不上传业务代码”不等于“零联网”。提供离线模式及 provider 说明；外部服务会见到请求出口地址。
- VPN/tunnel 提示与确认的 VPN 连接分开；检测到某个接口不直接断言所有流量经过代理。
- GUI 环境解析出的 Node/JDK 与用户特定交互 shell 可能不同；展示检测上下文，允许用户选择可执行路径，不能默认运行所有 shell 初始化脚本。
- HTTP 401/403、DNS 失败、TLS 失败、超时分开；连接得到响应不代表账户可以调用模型。
- 存在监听端口不是“端口冲突”；只有用户指定想使用的端口或明确失败证据时才报告冲突。
- 已用磁盘空间不等于可回收空间；扫描结果不要直接写“安全可释放”。Maven/开发目录可能有无法重新获取的本地内容，不能批量认定全可删。
- v0.1 建议 Cleaner 只读扫描；任何后续删除需独立风险设计、路径校验、用户确认与回收/恢复方案。

这些是避免误导的设计约束，需要实现验证，不是本报告声称已经对你的机器做过检测。

## H10 — 建议补齐：开源发布门禁与产品核心分离

Day 1 锁定本机构建流程与发布路线；不把签名问题留到最后一天才发现。共享 scheme、无个人路径、最低系统版本、第三方依赖许可证、日志脱敏应进入仓库规范。

Day 7 分开记录：源代码可构建、测试通过、安装包生成、签名、公证、外部机器启动测试。`notarization plan` 不能当成 `notarization passed`。无签名路径也可以有诚实的 source/preview release，但不要标成已经普遍验证的稳定安装包。

发布版本号、推送/打 tag、上传 release、改变账户/全局 CLI 设置属于有外部影响的动作，需要你的授权；修 UI 或运行仓库内测试不必逐步请求批准。

## 修订后的 7 天结构（建议，未改写你的原计划）

| Day | 主交付 | 核心验收 |
|---|---|---|
| 1 | 单一设计/工程、构建入口、Mock UI、隔离额度能力 spike | 能构建；四个配额指标；确定源数据与关键风险 |
| 2 | System → Snapshot → UI/Menu Bar → Soul 的一条真实闭环 | 真实采样、状态变化、取消/恢复、针对性测试 |
| 3 | Codex/Claude 最小配额接入及失败状态 | 脱敏 fixture、真实连接证据、过期/缺字段处理 |
| 4 | 网络和运行时/端口最小支持矩阵 | 检测上下文清楚；不把 hint 当结论 |
| 5 | 补缺、性能测量、范围冻结 | 无核心 blocker；可选 Cleaner 仅在进度允许时做 |
| 6 | 集成回归、UI/无障碍、Release Candidate | 不添加 Notch；修复失败项 |
| 7 | 独立工作目录构建、安装测试、发布材料 | 每种验证状态都有证据或明确未执行 |

7 天是目标，不是由模型名称或订阅额度保证的交付承诺。

## 执行方式

把本加固包放进已存在的仓库的 `review/` 目录，而不是覆盖根目录。让 Codex 读取 `review/CODEX-HARDENING-PROMPT.md`。
先只执行 Phase A（合并规范、构建、Mock 模型修正、任务账本），确认结果后再按修订后的真实任务队列推进。
本报告没有替你新建一套互相冲突的 AGENTS，也没有声称 MacSoul 已完成上述改动。

## 官方核验来源

以下来源用于接口/产品用法核验，不代表本机集成测试。

- OpenAI 模型目录：https://developers.openai.com/api/docs/models
- OpenAI 模型使用指导：https://developers.openai.com/api/docs/guides/latest-model
- Codex 配置参考：https://developers.openai.com/codex/config-reference/
- Codex Subagents：https://developers.openai.com/codex/multi-agent/
- Codex App Server：https://developers.openai.com/codex/app-server/
- Claude Code Statusline：https://code.claude.com/docs/en/statusline
- Claude Code 项目指令和导入：https://code.claude.com/docs/en/memory

原始文件的绝对路径、哈希及检查状态见 `static-checks.json`。报告中 `path:line` 指各原始文件自身行号。
