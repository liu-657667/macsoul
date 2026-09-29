# Day 2 System/Soul 内存口径收尾（2026-09-29）

## 范围与人工反馈

- 当前工作分支 `feature/system-soul`，未提交、未推送；沿用已有 SensorHub 与 Soul 状态机。
- 负责人对同时间窗口 CPU Live 给出 PASS：MacSoul 约 30–32%，活动监视器总体 User + System 约 27%；两者采样窗口不同。
- 修订前负责人对 Memory Used 给出 NEEDS_CHECK：活动监视器约 14.13 / 16 GB，旧 MacSoul 约 74–75%。**修订版数值随后由负责人亲自验收为 PASS**；算法仍被标明为 VM 估算，不把单次数值相近解释为精确同口径。
- Memory Pressure 继续 VERIFYING：未收到原生事件时数据仍为 `Unknown · Live`，普通摘要显示“监测中 · 实时”；没有进行内存耗尽试验。

## Memory Used 旧口径

原公式：`(active_count + wire_count + compressor_page_count) × vm_kernel_page_size / ProcessInfo.physicalMemory`。分子是 active 页、wired 页和压缩器占用的物理页；未计 inactive 页（包括未活跃的匿名应用页）、free 页及 file-backed 页，也没有独立加 speculative、purgeable 等重叠计数。全部 inactive 页被排除是低估的主要原因之一。百分比由原始字节计算；详情曾用 `ByteCountFormatter(countStyle: .memory)` 显示，采用 1024 进位但可能以 GB 标注，单位易混淆。

## Memory Used 修订口径

原生读数仍来自 `host_statistics64(HOST_VM_INFO64)`，总量仍来自 `ProcessInfo.physicalMemory`。新公式：

`usedBytes = physicalMemory - (free_count + external_page_count) × vm_kernel_page_size`

`usedPercent = usedBytes / physicalMemory × 100`

- 排除 `free_count` 与 `external_page_count`：后者是 VM 的文件映射页计数，**不等同于**“所有可即时回收的缓存”。`speculative_count` 已包含在 `free_count` 中，因此没有再次减去。
- 其余物理内存被计入估算值：包括未活跃的匿名应用页、wired 页与压缩器占用页。没有把 active、inactive、wired、compressor 等计数再次相加，以免交叠或双计。
- `internal_page_count`、`purgeable_count`、swap 等未另作加减；内存压力仍由独立的 Dispatch memory-pressure 事件决定，绝不从 Used % 推断。
- 这是基于 macOS VM 类别、面向用户的 **“内存已用”估算**，尽量贴近活动监视器把 App Memory、Wired、Compressed 与 Cached Files 分开的呈现；并非宣称使用苹果未公开的活动监视器精确公式。采样时刻和类别边界会造成差异。
- `usedBytes` 和 `totalBytes` 先作原始字节百分比运算，详情明确以 `GiB = bytes / 2^30` 展示两位小数；不再混用模糊的 GB 标签。

参考：[Apple 活动监视器内存说明](https://support.apple.com/zh-cn/guide/activity-monitor/actmntr1004/mac)；MacOSX SDK `mach/vm_statistics.h` 对 `free_count`、`speculative_count` 和 `external_page_count` 的字段说明。

## 本轮 UI 与 Soul

- System 详情展示 GiB 数量和计算说明。Overview/Menu Bar 共享同一 Snapshot 的百分比。
- Soul 在压力未知时只说“处理器负载平稳；内存压力仍在监测中”；压力恢复正常时才使用已有的系统平稳文案。阈值、冷却、优先级、恢复状态机未重设计。
- Overview 的 AI Coding 标题旁增加轻量“模拟”标识；原有配额窗口和 fixture 未修改。

## 验证与限制

| 项目 | 结果 | 证据 |
|---|---|---|
| `./scripts/build.sh` | PASS，exit 0 | `.artifacts/build.log` |
| `./scripts/test.sh` | PASS，30 个单测、0 失败，exit 0；含纯计算、未知压力文案测试 | `.artifacts/test.log` |
| `./scripts/verify.sh` | 本轮最终 PASS，exit 0；doctor/build/unit/progress tests/visual assets/ledger 全部 PASS | `.artifacts/verification.json`；最终工作树指纹 `80a56a5b2124c1a26ec0430a44498ea090c4df6ef41a658954d0a8fc73950954` |
| 原生基本观察 | 首次 CPU 未知；后续 CPU 30.1%；内存 14,786,772,992 / 17,179,869,184 字节（86.1%）；压力事件未到达，保持未知 | `.artifacts/system-observation-closeout.log`；`swiftc MacSoul/Models/MacSoulModels.swift MacSoul/Models/SystemSensors.swift scripts/observe-system.swift -o .artifacts/observe-system && .artifacts/observe-system` |
| 本修订版人工 UI / Activity Monitor 同时对照 | Memory 数值 PASS，负责人已确认；其他双入口和 Live/Mock 验收见 `reports/day-2-system-soul-2026-09-29.md` | 已正常退出旧版 PID 50871，启动 `/Users/mrliu/githubWorkspace/macsoul/build-preview/MacSoul.BMaNCO/MacSoul.app`（当时 PID 65736）；Debug dylib SHA-256 与本工作树构建产物一致 |
| 实机 sleep/wake、真实 warning/critical 压力事件 | NOT_RUN | 未执行压力试验 |
| Performance（Release、无调试器、持续测量） | NOT_RUN | 无 |
| 真实 AI Provider | NOT_RUN | 未接入 |

本次观察发生于 `2026-09-29T02:18:06Z` 前后，单次 1.1 秒间隔；它不是负责人同时段活动监视器复核。Disk、Battery、进程、Network、AI Provider 等不在本轮接入范围。

第一次 `verify.sh` 的源码构建、单测等均通过，但 ledger 因前一工作树指纹而失败。旧证据保留在 `evidence_history`；用本轮已经通过的相同命令和日志刷新当前证据后再次运行，最终 `verify.sh` exit 0。没有修改历史包哈希或原始任务点数。
