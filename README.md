<p align="center">
  <img src="MacSoul/Resources/MacSoulBrand.xcassets/MacSoulAppIcon.appiconset/icon_128x128@2x.png" width="96" height="96" alt="MacSoul 小灵魂图标">
</p>

<h1 align="center">MacSoul</h1>

<p align="center"><strong>一个有点嘴欠的 macOS 开发者伴侣。</strong><br>Your Mac knows what you're building.</p>

<p align="center">原生 SwiftUI · 菜单栏入口 · 系统状态 · AI 配额 · Soul</p>

<p align="center">简体中文 · <a href="README.en.md">English</a></p>

MacSoul 希望把系统状态、AI 编程额度、网络和本地开发环境放进一个原生 macOS 应用，让你不用在多个窗口之间来回寻找答案。住在里面的小灵魂，则会把需要关注的状态翻译成一句话：

> - CPU 持续高负载：「我的脑子要爆炸了。」
> - 内存压力严重：「我的胃快撑爆了。」
> - 状态恢复：「呼……终于安静了。」

**有趣的反馈是入口，清楚、可信的数据才是目的。**

> **当前为开发预览。** 应用默认使用内置模拟数据；在设置中选择「实时系统」后，CPU、内存已用/总量由 macOS 原生数据提供，Soul 可由真实 CPU 与内存状态驱动。内存压力接入了原生事件，但真实 warning/critical 事件尚未观察到。磁盘、电池、进程仍为模拟或待实现；AI 配额、网络和开发环境尚未接入真实 Provider。正式性能测量尚未进行，不能当作已完成的日常监控工具。下表明确区分实时功能与界面预览。

![MacSoul 产品概念主视觉，非当前 App 截图](assets-source/reference/macsoul-product-hero.png)

> 这张图是早期产品概念，**不是当前 App 截图或功能验收证据**。其中的 VPN、服务延迟和清理按钮尚未实现；图中的指标布局不代表当前实时界面。

## 核心功能与当前状态

| 模块 | 要解决的问题 | 当前主分支 |
|---|---|---|
| **Soul** | 用角色表情和简短文案回应机器状态；严重时提醒，恢复后反馈，不反复打扰 | 六种角色图片与模拟场景已接入；实时模式可由真实 CPU / 内存状态驱动，真实内存压力 warning/critical 事件仍待观察 |
| **系统状态** | CPU、内存压力、磁盘、电池，以及哪些进程占资源 | CPU、内存已用/总量为 Live；内存压力来自原生事件，未收到事件时显示未知；磁盘、电池仍为模拟，进程分析待实现 |
| **AI 配额** | 查看 Codex / Claude Code 实际适用的 5h / Week 窗口及重置时间 | 动态窗口、Week-only、0%、缺失、失败和过期场景可预览；真实账户待接入 |
| **网络** | 了解公网 IP、代理线索与服务连通性 | 页面预览；真实检测待实现 |
| **开发环境** | 看清运行时版本、路径与监听端口 | 页面及模拟端口展示；真实检测待实现 |
| **开发缓存** | 解释开发缓存占了多少空间、清理有什么风险 | 界面预览；真实扫描未实现，不执行删除 |

主窗口用于看细节，**菜单栏是所有 Mac 共用的快速入口**。不需要带刘海的屏幕；当前范围不实现 Notch 展示。

### AI 配额：有什么窗口，就显示什么

MacSoul 的目标是展示账户实际提供的额度窗口，而不是根据套餐名称猜测限制。当前 Mock App 已能预览这些情况：

| 返回的窗口或状态 | 展示方式 |
|---|---|
| 只有 Week，5h 明确不适用 | 摘要只显示 Week，不补一个假的 5h 进度条 |
| 同时有 5h 和 Week | 显示两个窗口 |
| 有效窗口已用 0% | 正常显示 0%，不当作缺失 |
| 未报告、请求失败、数据过期 | 显示对应状态，不冒充不限额或最新数据 |

主窗口与菜单栏共用同一份状态。AI 模块不做 Token 成本分析、Agent 会话管理或自动模型选择。这里讨论的是 **Codex / Claude Code 配额**，不是把 ChatGPT 聊天额度混在一起。

设置中可以切换 MacSoul 自身的跟随系统、浅色和深色外观，以及简体中文和英文；这些选择不更改 macOS 的全局设置。

### Soul：有个性，但不打扰

正常、忙碌、脑子过载、胃撑、低电量、休息，是同一个小灵魂的不同状态。当前可在模拟场景里预览图片和文案。

实时 Soul 联动使用本地规则、持续阈值、冷却与恢复反馈，不依赖大模型生成吐槽；CPU 瞬时尖峰不会直接触发状态切换。

## 从源码体验开发预览

需要 macOS、完整 Xcode 和 Python 3。工程最低部署目标是 macOS 13；这不代表所有 macOS / Xcode 组合都已经测试，工具链与验收记录见[开发指南](docs/DEVELOPMENT.md)。体验当前预览不要求 Codex、Claude Code 或 AI API 密钥。

```bash
git clone https://github.com/liu-657667/macsoul.git
cd macsoul

./scripts/doctor.sh
./scripts/verify.sh
./scripts/run-mock.sh
```

也可以在 Xcode 中打开工程：

```bash
open MacSoul.xcodeproj
```

运行预览脚本前，请先正常退出已运行的 MacSoul。应用默认使用开发预览数据；在 **Settings → 系统数据来源** 可选择「实时系统」，只采集本机 CPU 与内存。切回开发预览后，可选择 `Codex: Week only`、高 CPU、内存压力等模拟场景；这些场景不会修改真实账户套餐，也不会给电脑制造真实高负载。

本页提供的是源码预览流程，不承诺已发布可直接安装的正式安装包。

## 隐私与产品边界

本地优先是产品的设计原则。当前预览默认使用内置模拟数据；选择「实时系统」后，会在本机采集 CPU 与内存，不访问 AI 账户。网络与开发环境仍无真实 Provider。后续网络检查会明确区分本地检测与外部请求；公网 IP 查询本身需要访问外部服务，不能把它描述成“完全不联网”。

MacSoul 不负责写代码，不提供杀毒或防火墙能力，也不会把“占用的空间”直接等同于“安全可删除的空间”。当前没有自动清理，更没有一键删除真实开发数据。

## 接下来做什么

| 阶段 | 交付重点 |
|---|---|
| **当前：部分实时预览** | 原生窗口与菜单栏、Soul 图片、模拟场景；实时 CPU / 内存经共享快照驱动界面与 Soul；构建和测试入口 |
| **下一步：其他系统指标** | 按任务账本继续评估磁盘、电池和进程；内存压力真实事件继续验证 |
| **后续：真实集成** | Codex / Claude Code 配额、网络、运行时与端口检测 |
| **后续：扩展与发布** | 按任务账本推进只读缓存分析、性能验证、安装与发布 |

这是产品方向，不是已完成清单或固定交付日期。[当前任务状态](docs/STATUS.md)记录开发进度；人工界面、真实性和性能验收分别记录，不互相代替。

Phase A 历史视觉验收仍为部分通过，菜单栏小图标保持 DRAFT。实时 CPU、内存数值和主窗口/菜单栏联动已通过人工验收；内存压力真实事件、正式性能测量及真实 AI Provider 仍未通过或未运行。见[System/Soul 报告](reports/day-2-system-soul-2026-09-29.md)与[当前任务状态](docs/STATUS.md)。

## 参与开发

欢迎围绕 macOS / Xcode 兼容性、界面可读性、可复现 Bug 和真实数据接入提交 [Issue](https://github.com/liu-657667/macsoul/issues) 或 Pull Request。反馈请注明环境、分支或提交号、复现步骤，并先移除日志和截图里的敏感信息。

[开发指南](docs/DEVELOPMENT.md) · [产品设计](docs/DESIGN.md) · [技术架构](docs/ARCHITECTURE.md) · [任务状态](docs/STATUS.md)

使用 Coding Agent 开发时，从 [AGENTS.md](AGENTS.md) 和当前任务开始。普通体验者不需要先阅读七天计划、审查报告或模型配置。

## License

MacSoul 有权授权的自有代码采用 [MIT License](LICENSE)，版权声明为 `Copyright (c) 2026 liu-657667`。Cleaner 扫把图标来自 Phosphor Icons；其原始版权和许可随 App 收录于 [ThirdPartyNotices.txt](MacSoul/Resources/ThirdPartyNotices.txt)。其他第三方内容保留原有许可与声明，视觉资源来源见[资源说明](docs/ASSET-SOURCES.md)。历史输入、参考图和第三方素材不因根目录的许可证自动获得新的授权。
