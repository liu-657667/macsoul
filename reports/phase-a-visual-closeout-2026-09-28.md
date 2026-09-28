# Phase A 第二轮视觉验收收尾

日期：2026-09-28（Asia/Shanghai）。范围按 `review/MacSoul-Visual-Acceptance-2026-09-28.md` 的 VIS-01 至 VIS-04；先前的截图结论仍为 **PARTIAL_PASS**。本轮修订版尚未重启做人工界面复核，不能把自动测试写成视觉全通过。

## 修订与原因

| 项目 | 修订 | 当前结论 |
|---|---|---|
| VIS-01 | `PortItem.displayPort` 用十进制原样字符串；Overview 与 Dev 均使用它。 | 8080、3000、3306、65535 的中英文路径单测通过；无复制功能。 |
| VIS-02 | 主窗口、菜单栏及 AI Coding 详情均使用同一个 `AppStore.snapshot` 和 `displayNow`；一个 30 秒共享 UI 时钟推进显示，不刷新 Mock 截止时间。 | 固定时钟单测通过；同一时刻双入口人工截图待复核。 |
| VIS-03 | 七个 Soul Mock 场景有对应中英文趣味文案；两入口仍取同一个 Snapshot。 | 文案映射单测通过；两入口新截图待复核。 |
| VIS-04 | 辅助文字用动态主文字的 72% 强度；严重内存压力、4% 电池和 95% 配额增加明确文字与警告符号。 | 构建通过；深色实际可读性待复核。 |

之前的倒计时差异出现在两处 `TimelineView(.periodic(from: .now, by: 60))` 各自独立起步的代码中。Mock 截止时间本来就在 `MockProvider.snapshot(now:)` 中生成，且 `@StateObject AppStore` 在主窗口和 Menu Bar 间共享；未发现弹层打开时调用 `refresh`。修订后显示时间也取同一 `AppStore.displayNow`，所以同一快照、同一时刻的两处摘要使用相同数值与格式化规则。短提示按剩余天/小时/分钟截取；精确跨小时边界时可能从“4天6小时”变为“4天5小时”，但两处会同时取同一时钟值。到期或采样超过 300 秒，没有新快照便标记过期，保留旧百分比，不自动归零。正常 Mock 场景如果被打开后长期不主动切换，会按此规则老化；过期截图不能单独证明启动时即过期。尚未用真实 UI 反复开合弹层验证时序。

Mock 的全局“模拟数据”标记保留。Week-only、未报告、有效 0%、请求失败、过期和无电池的状态规则未修改，原有回归测试继续通过。`memoryPressure` 与内存已用百分比仍是独立字段，严重压力场景没有伪造 95% 内存使用率。

## 验证证据

本轮验证工具链：macOS 27.0、Xcode 27.0 (27A266a)。`./scripts/verify.sh` 最终退出 0；UTC 检查时间 `2026-09-28T14:56:32.762393+00:00`。Git 基底 `835c8870a9c5791c7375c85c1d8bac5b2a5d2ad9`；工作树指纹 `06ac3c4278ad91b154a80c32919a5db3942fef28c521bedc2ae1d474d5fd2294`。未提交改动不由基底 revision 单独表示，命令详情见 `.artifacts/verification.json`。

| 维度 | 结果 | 证据 |
|---|---|---|
| doctor | PASS | `./scripts/doctor.sh`，退出 0，`.artifacts/doctor.log` |
| build | PASS | `./scripts/build.sh`，退出 0，`.artifacts/build.log` |
| unit | PASS | `./scripts/test.sh`，21 个 XCTest、0 失败，退出 0，`.artifacts/test.log`；新增端口、中英文 Soul 文案、共享时钟边界与严重配额测试。 |
| progress / assets | PASS | `python3 scripts/test_progress.py`、`python3 scripts/verify-visual-assets.py`，均退出 0；`python3 scripts/verify_progress.py` 复核 59 项、原计划 76 点。 |
| manual UI：本轮修订版 | NOT_RUN | 负责人授权后已退出旧版 PID 88049，`./scripts/run-mock.sh` 退出 0，修订版从 `build-preview/MacSoul.jAu7YR/MacSoul.app` 启动，PID 19397。尚未收到修订版双入口、Soul 文案或深色状态的人工复核。先前 40 张图只作问题和历史局部通过证据。 |
| performance | NOT_RUN | 没有 Release 无调试器测量。 |
| live provider | NOT_RUN | 仍只使用内置 Mock。 |
| Dock | PASS（负责人确认） | 负责人在本轮明确确认当前 Dock 图标实际尺寸、辨识度和品牌感，允许继续使用；轻微外发光或黑边精修留待以后，不阻塞本轮。菜单栏小图标仍为 DRAFT。 |

账本 `tasks.json` 新增零点数 VIS-01 至 VIS-04，保留原 76 点及证据历史。VIS-01 自动验收完成；VIS-02 至 VIS-04 保持 `verifying`，等待负责人在修订版上查看同一场景的主窗口/菜单栏、Soul 文案和深色严重状态。Dock 的单项人工确认已记入 VA-01；VA-01 的其他视觉条件仍待验收。静态截图不等于所有交互、真实数据或性能验收。
