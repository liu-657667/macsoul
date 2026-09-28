# MacSoul PRD — 合并版概述

> 本文件描述产品意图。范围和界面具体规则以 SCOPE.md / DESIGN.md 为准；旧完整 PRD 在 reference/early-product-docs/PRD.md。

## 定位

MacSoul 是本地优先的原生 macOS 开发者控制中心：专业数据帮助找问题，Soul 用克制的拟人反馈提供记忆点。
入口是所有目标 Mac 通用的 Menu Bar 和 SwiftUI 主窗口，不把核心能力绑在刘海上。

## 核心模块

| 模块 | 要解决的问题 | 本轮限制 |
|---|---|---|
| System | CPU、内存压力、磁盘、电池、耗资源进程 | 共享数据源；无电池/权限缺失要降级 |
| Soul | 大脑/胃/家/体力等隐喻，异常和恢复反馈 | 本地规则；持续阈值、滞回、冷却；不乱通知 |
| AI Coding | Codex / Claude Code 各自 5h + Week 已用百分比与重置 | 不加 Token/费用/会话；来源、新鲜度、缺失要真实 |
| Network | 出口 IP、系统/环境代理、隧道提示、轻量连通性 | hint 不当结论；探测可关闭；精确位置不是必需 |
| Dev | Java/Node/Python/Go 版本与路径、监听端口/PID | 呈现检测上下文；不暗自执行 shell 启动脚本 |
| Cleaner Lite | 按需统计开发目录大小与风险说明 | 首次只 Mock；后续只读扫描，删除不在 Phase A |

## 两个展示入口

主窗口：Overview / System / Network / AI Coding / Dev / Cleaner / Settings。
Menu Bar：Soul 一句话、CPU/内存、Codex 5h+Week、Claude 5h+Week、网络简要状态。
两个入口共享相同 Snapshot；数据缺失显示 —，不混用假数据、真实数据和估算。
概念效果图在 reference，仅作视觉气质参考；以具体设计规则为准。

## Soul 互动

持续 CPU 高负载：我的脑子要爆炸了。恢复后：呼……终于安静了。
真实内存 critical 压力：我的胃快撑爆了。不能仅因缓存让使用率变高就制造报警。
每条可链接对应诊断页面，默认为应用内轻提示。多数指标波动不弹系统通知。

## 非目标

账号/云同步、Agent 管理、代码生成、Token/成本分析、自动推荐模型、PRD/架构工具、全盘自动清理、杀毒/防火墙。
Notch、历史时间线、项目拓扑是后续版本，不插入本次 Phase A。

## 开发与验收

第一步是 Phase A：构建工程、Mock 契约、设计统一、证据账本；不是已经接通真实服务。
随后按七天任务基线迁移后的依赖实施。真实 quota 读取和 unavailable UI 分别验收。
build/unit/manual UI/performance/live provider/release 要各自有证据，不能用包完整性检查代替。
性能采取事件/分层采样/按需扫描；资源预算见 PERFORMANCE.md，未测量不宣称达标。
