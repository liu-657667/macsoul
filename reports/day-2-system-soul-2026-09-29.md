# Day 2: System → SensorHub → Soul（2026-09-29）

## 最终人工验收补录

- 负责人已确认：Live CPU **PASS**；Live Memory 数值 **PASS**；Overview、System、Menu Bar 共用实时状态 **PASS**；菜单栏与主窗口数据同步 **PASS**；Live/Mock 边界展示 **PASS**；Soul 使用真实 CPU 状态 **PASS**。
- 主窗口关闭后采集继续；连续关闭、重新打开主窗口 **5 次**正常；Menu Bar 连续打开、关闭正常。D2-01 与 D2-07 据此转为 `done`，D2-02 与 D2-06 保持 `done`。
- D2-03 保持 `verifying`：Memory Used 数值已验收，Memory Pressure 的自然 warning/critical 事件尚未观察到。未知仍是未知，不代填 Normal。
- 未进行 CPU 满载或内存耗尽测试；实机 sleep/wake 未单独观察；正式 Performance 测量 **NOT_RUN**；真实 AI Provider **NOT_RUN**。
- 内存算法、GiB 单位及修订版证据见 `reports/day-2-system-soul-memory-closeout-2026-09-29.md`。下文的首次集成数值保留为历史记录，不代表最终内存公式。

### 最终命令证据

- `./scripts/build.sh`：exit 0，`.artifacts/build.log`。
- `./scripts/test.sh`：exit 0，30 个单测、0 失败，`.artifacts/test.log`。
- `./scripts/verify.sh`：最终 exit 0；doctor、build、unit、progress tests、visual assets、ledger 均 PASS，`.artifacts/verification.json`。对应基底 HEAD `a5e4a21af0507e26cfb807b985e7b37d88832e99`，工作树指纹 `80a56a5b2124c1a26ec0430a44498ea090c4df6ef41a658954d0a8fc73950954`。
- 第一次最终 `verify.sh` 的构建与单测已通过，只有 ledger 因之前工作树指纹失效而失败；旧 evidence 保留至 `evidence_history`，刷新本轮实际通过的证据后复跑成功。未修改历史包哈希或任务点数。
- Xcode 工程的确定性生成脚本现保留 `ThirdPartyNotices.txt` 资源；构建后的 App 包中已检查到此文件。

## 范围与状态

- 分支：`feature/system-soul`；基底 HEAD：`a5e4a21af0507e26cfb807b985e7b37d88832e99`；工作树有本轮未提交改动。
- 本轮指纹：`988c996d5bc8aa7d5313277a5fde234b635595764b18ea43c3521a645ad34897`。
- D2-02（原生 CPU）、D2-06（Soul 规则）代码与单测验收完成，账本记 `done`。
- 首次集成时 D2-01、D2-03、D2-07 曾记 `verifying`；最终状态以本页补录和生成的 `docs/STATUS.md` 为准。
- D2-04/05 与其他后续任务仍为 `todo`；Disk、Battery、Network、Dev、AI Quota、Cleaner 等保持原有 Mock 或不可用状态。

## 实现与口径

- 单一 `AppStore` 持有一个 `SensorHub`。Overview、System、Menu Bar 和 Soul 读取同一 `AppSnapshot`；窗口/页面切换仅更新采样间隔。System 页面可见约 1 秒；其余状态约 5 秒。`start/stop` 幂等，旧采集循环结束后才重启采集源。
- CPU：`host_statistics(HOST_CPU_LOAD_INFO)` 的 user + system + nice 忙碌 tick 占两次样本全部 tick 的比例，为**全机 0–100%**。首次/无效样本为未知；与 Activity Monitor 的单进程多核百分比口径不同。
- 内存：首次集成使用 active + wired + compressor 页估算，漏掉未活跃匿名页；现已修订为 `ProcessInfo.physicalMemory - (free_count + external_page_count) × vm_kernel_page_size`，原始字节算百分比，详情以 GiB 呈现。它仍是估算，不声称与活动监视器内部算法完全相同。Memory Pressure 使用独立的 `DispatchSourceMemoryPressure` 事件；收到事件前保持未知，不推断正常。
- Soul：单调 uptime 时钟可注入；CPU >85% 连续 15 秒、>95% 连续 20 秒，<60% 连续 30 秒恢复。内存 warning/critical 优先级独立于 Used%，冷却 30 分钟，采样中断和 sleep/wake 清除待完成的持续计时。没有 LLM 或 Shell 采样。
- Settings 选择 `Developer Preview` 或 `Live System`。实时模式只替换 CPU、内存与由其驱动的 Soul；整个 App 不标成完全 Live。其余模拟项保留显式来源提示。
- 生成工程脚本只补入现有 Cleaner asset catalog，使新克隆测试能加载已入库的扫把资源；没有重建工程或 Harness。

## 验证证据

| 项目 | 结果 | 证据 |
|---|---|---|
| `./scripts/build.sh` | PASS，exit 0 | `.artifacts/build.log` |
| `./scripts/test.sh` | 首次集成 PASS，29 个单测；最终修订见下方补录 | `.artifacts/test.log` |
| `./scripts/verify.sh` | PASS，exit 0；doctor/build/unit/progress tests/visual assets/ledger 均 PASS | `.artifacts/verification.json` 及关联日志 |
| 原生基本观察 | PASS，首次 CPU 未知，约 1.1 秒后全机 CPU 35.1%；内存 13,652,672,512 / 17,179,869,184 字节（79.5%）；压力事件尚未发生，状态未知 | `.artifacts/system-observation.log`；`swiftc MacSoul/Models/MacSoulModels.swift MacSoul/Models/SystemSensors.swift scripts/observe-system.swift -o .artifacts/observe-system && .artifacts/observe-system` |
| 人工 UI | 首次集成 PARTIAL；最终人工验收结论见本页顶部 | `./scripts/run-mock.sh` exit 0，`build-preview/MacSoul.FIEl3p/MacSoul.app`，当时运行 PID 50871 |
| Performance（Release、无调试器、持续测量） | NOT_RUN | 无 |
| 真实 AI 配额 Provider | NOT_RUN | 未接入 |
| 实机 sleep/wake 与真实 warning/critical 压力事件 | NOT_RUN | 不进行压力测试 |

首次 `verify.sh` 的构建、单测等通过，但 ledger 因历史已完成任务的**旧工作树指纹**失败。保留原 evidence 到 `evidence_history`，以本轮实际通过的命令/日志刷新当前 evidence 后再次运行 `verify.sh`，最终 exit 0。没有改动原七天计划包哈希或原始任务点数。

原生观察使用 1.1 秒间隔；应用实际间隔随页面在约 1 秒与约 5 秒之间切换。本轮未打开 Activity Monitor 做同时间窗口对照；瞬时数字不应要求相同，尤其不能拿其单进程 CPU 口径直接比较全机 CPU。未执行长时间满载或内存耗尽测试。

首次供人工验收时，桌面随后运行了 `docs-project-intro` 工作树的旧构建（PID 48574），其设置页没有实时模式入口。经负责人明确允许，仅对该旧进程发送 SIGTERM；确认退出后重新启动本分支构建。新 App 的 `MacSoul.debug.dylib` 与本分支 Debug 产物 SHA-256 相同，负责人已确认新的设置入口可见。此项只证明入口显示，未替代实时数据与交互验收。

## PR #2 审查后修复（2026-09-29）

- `SoulEngine.suspend()` 现在清除持续阈值计时并把瞬时状态及展示重置为 `observing`；保留公告冷却历史。唤醒后只由新 CPU / 内存压力样本建立状态，未知压力不恢复旧 `memoryCritical`。
- 使用可注入时钟补测 `memoryCritical`、`stressed`、`brainOverload` 跨 suspend 后的状态；没有执行真实睡眠、CPU 满载或内存耗尽测试。
- 合并 `origin/main` 时仅两份 README 冲突，沿用 main 的项目介绍结构，并保留本分支已验证的部分实时状态；`docs/DEVELOPMENT.md` 原样来自 main。
- 本轮 `./scripts/build.sh` exit 0；`./scripts/test.sh` exit 0，32 个测试、0 失败；`./scripts/verify.sh` 最终 exit 0，doctor/build/unit/progress tests/visual assets/ledger 均 PASS。证据在 `.artifacts/build.log`、`.artifacts/test.log`、`.artifacts/verification.json`，源码与验证输入指纹为 `b2f87dd4b0755290d7dccdf7979e7563b21949e3b2f4a404433d5763b91e9e6f`。首次 verify 的 ledger 因旧指纹失败；保留旧证据于 `evidence_history` 后，按已通过的实际命令刷新当前证据并重跑通过。
- 上述原有人工验收记录保持不变。Memory Pressure 的自然 warning/critical 事件继续 VERIFYING；正式 Performance 测量和真实 AI Provider 仍为 NOT_RUN。本轮未新增人工 UI 验收。

## PR #2 Soul 公告冷却修正（2026-09-29）

- 根据 `docs/SOUL-ENGINE.md` 的同事件类别 30 分钟冷却规则，公告键改为 CPU、Memory、Recovery；原状态优先级和 15/20/30 秒阈值保持不变。严重程度升级时状态、图像和 mood 立即更新，同类别公告文案不重复。`suspend()` 保留冷却历史。
- 注入时钟的单测覆盖 stressed → brainOverload、memoryWarning → memoryCritical、同类别冷却到期后再次公告，以及 recovery 的首次和冷却内再次进入；没有进行真实睡眠或压力试验。
- 本轮 `./scripts/build.sh` exit 0；`./scripts/test.sh` exit 0，35 个测试、0 失败；`./scripts/verify.sh` 最终 exit 0，doctor/build/unit/progress tests/visual assets/ledger 均 PASS。证据在 `.artifacts/build.log`、`.artifacts/test.log`、`.artifacts/verification.json`，源码与验证输入指纹为 `94eab9948ad76b1382f833d068f00d1adb53e16a3ba7e90fc97471f9348f89f0`。首次 verify 的 ledger 仅因旧指纹失败；旧证据保留于 `evidence_history`，当前证据按本轮实际通过的命令更新后复跑通过。
- 既有人工验收结论不变。Memory Pressure 的自然 warning/critical 事件继续 VERIFYING；正式 Performance 测量与真实 AI Provider 仍为 NOT_RUN；本轮人工 UI 为 NOT_RUN。
