# Phase A 进度与验收证据

日期：2026-09-28（Asia/Shanghai）。范围：A1–A4；停止在负责人验收点。初始化包中的源码和历史报告不计为已完成任务。

## 状态

| ID | 状态 | 当前证据 / 待验收 |
|---|---|---|
| A1 设计与双入口四窗口 | verifying | `docs/SCOPE.md` + `docs/DESIGN.md` 为产品规范；Overview/AI Coding 已由 Agent 在运行 App 的可访问性树中观察到四窗口；Menu Bar 弹出层及负责人手工检查待做 |
| A2 工程与固定入口 | done | 共享 `MacSoul` scheme、App 与 XCTest target；build、unit 和新 DerivedData 构建通过 |
| A3 共享 Snapshot/Mock 契约 | verifying | 纯逻辑测试通过；缺失/过期/Mock 可见性需要负责人在双入口确认 |
| A4 结构化账本 | done | 原计划 48 个计分任务、76 点保留；正例与六个反例、当前账本校验通过 |
| D1-01 / D1-03 | done | 工程/test target 与 typed Mock Snapshot/注入通过当前构建及测试证据，共 4 原计划点 |
| D1-02 / D1-04 | verifying | 主窗口导航与 Mock 页面已有 Agent UI smoke，菜单栏及负责人验收待做 |

原始计划验收 4/76 点（D1-01、D1-03）；批准调整后同为 4/76 点。未改原始点数、优先级或范围，没有延期批准。A1/A3 保留 `verifying`，不会用 Agent 浏览代替负责人验收。原七天计划中 2 项有证据完成、2 项界面相关任务待验收，其余未开始；真实额度与系统采样仍待后续独立工作单元。

## 实际环境与包检查

- macOS 27.0 / arm64；Xcode 27.0 (27A266a)；Swift 6.4；Codex CLI `0.158.0-alpha.2.1`；Claude CLI UNKNOWN（未安装或不在 PATH）。当前会话精确模型 ID 与角色配置 UNKNOWN。
- 工程设置最低 macOS 13.0；只在 macOS 27.0 实测，旧系统兼容性 NOT_RUN。
- 初始目录没有 `.git/`，故 Git branch/revision 为 UNKNOWN。未初始化仓库或推送。证据对应工作树 SHA-256 指纹：`ee74551082f780a87b5332a0ce1fdb2db3b731b40ad55684011337291f64b5c9`。
- 初始隐藏文件 `.gitignore` 和 `.codex/config.toml` 都缺失；已补 `.gitignore` 以隔离本地构建证据，未启用或重造项目 Codex 配置。`python3 scripts/check_bundle.py` 当前退出 1，唯一缺口为 `.codex/config.toml`；包完整性检查本身不证明 App 质量。
- 项目级 Codex 配置因文件不存在而未生效；Codex 客户端加载状态不可确认。`CLAUDE.md` 已有 `@AGENTS.md` 显式导入，但 Claude CLI 不可用，实际加载 UNKNOWN。未修改任何全局配置。

## 验证矩阵

| 项目 | 状态 | 实际命令 / 证据 |
|---|---|---|
| doctor | PASS | `./scripts/doctor.sh`，退出 0，`.artifacts/doctor.log` |
| build | PASS | `./scripts/build.sh`，退出 0，`.artifacts/build.log` |
| fresh build | PASS | `xcodebuild -project MacSoul.xcodeproj -scheme MacSoul -configuration Debug -destination 'platform=macOS' -derivedDataPath .artifacts/CleanFinalDerivedData CODE_SIGNING_ALLOWED=NO build`，退出 0，`.artifacts/build-clean-final.log` |
| unit | PASS | `./scripts/test.sh`，退出 0；6 个 XCTest 通过，`.artifacts/test.log` 和 `.artifacts/MacSoulTests.xcresult` |
| progress | PASS | `python3 scripts/test_progress.py`、`python3 scripts/verify_progress.py`，均退出 0；`.artifacts/progress-tests.log`、`.artifacts/progress-verify.log` |
| full verify | PASS | `./scripts/verify.sh`，退出 0；`.artifacts/verification.json` 与 `.artifacts/verify-console.log` |
| Mock App 启动 | PASS | `open .artifacts/DerivedData/Build/Products/Debug/MacSoul.app`，退出 0；进程 `MacSoul` 启动，PID 65455（当次观察） |
| Agent UI smoke | PARTIAL | Overview 和 AI Coding 窗口可访问性树中看见 Codex/Claude Code 的 5h/1 week 已用值、reset、Mock/source/freshness，且进度匹配；Menu Bar 弹出层未取得可核验观察 |
| manual UI（负责人） | NOT_RUN | 需打开主窗口及菜单栏并确认四窗口、Mock 标记、缺失/过期 fixture；Agent 的 UI smoke 不算人工批准 |
| performance | NOT_RUN | 未做 Release、脱离调试器的定时 CPU/内存测量 |
| live provider | NOT_RUN | 无系统、网络、Codex 或 Claude 真实采集 |

`.artifacts/` 被 Git 忽略；换机器或源码变化后必须重跑固定入口。`tasks.json` 的 done 证据必须匹配当前指纹，旧证据自动失效。

## 与初始化包冲突的修正

- Menu Bar 原源码只有两行 5h；现复用 `QuotaRow` 绘制两家各两个独立窗口。
- Overview/Menu Bar/System 原有固定 CPU/RAM 文本与动态进度混用；现数字与进度都来自共享 `AppSnapshot`。
- 原额度模型使用必填 Double 与文字 reset、刷新时随机 UUID；现用 0–100 百分比、可空窗口、`Date?` reset、稳定 provider ID，并区分 mode、freshness、source、sample time。
- 原 Cleaner 显示未扫描的“可回收 12.8 GB”；现显示扫描未运行。Settings 的无效交互开关改为明确不可用说明。
- 历史 `review/AUDIT.md` 与 `reference/` 保留原样，不作为当前验收结果。

## 下次第一项

负责人在当前 Mock App 主窗口和 Menu Bar 完成人工 UI 验收，重点核对两家四窗口、Mock 标记、reset、缺失/过期状态及数字与进度一致。若确认，记录人工确认后再将 A1/A3 从 `verifying` 更新为 `done`；本轮不进入真实 Provider 或后续开发。
