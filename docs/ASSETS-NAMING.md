# MacSoul 资源命名规范 v0.1

## 当前资源维护入口 — 2026-10-08

资源已接入公开 v0.1.0，无需按初始 ZIP 流程重新导入。菜单栏当前使用 **MacSoulMenuTemplateDraft**，并非尚未启用，也不代表正式美术全部定稿。Owner 的 Dock 单项认可、其他视觉条件及增量 verifying 见 [历史视觉 closeout](../reports/phase-a-visual-closeout-2026-09-28.md)；后续 Menu Bar/Mock/Live 的实际观察与限制见 [FINAL](../reports/FINAL.md) 和 [发行说明](RELEASE.md)。不扩展资源来源、许可证或 Owner 美术批准范围。

以下初始导入、候选说明与未勾 checklist 为 **Historical / Initial integration reference**，不是要求重新接入或全面 PASS。


## 1. 品牌与适用范围

品牌方向：已选定的“小幽灵 + 细星环”。本文件规定图片资源的名字、状态映射和调用方式；不覆盖产品范围、监控阈值、配额口径或既有 Soul 状态机。

本批是**静态资源**。真实/Mock 数据来源由现有 AppStore / Snapshot 管理；资源本身没有“实时能力”。

## 2. 三层命名

| 层次 | 约定 | 例子 |
|---|---|---|
| 原始图片文件 | 小写 kebab-case；原稿加 `-source` | `macsoul-app-icon-source.png`、`soul-low-battery.png` |
| Xcode asset 名称 | `MacSoul` 前缀 + PascalCase；不用扩展名 | `MacSoulLowBattery` |
| Swift 状态 case | lowerCamelCase，复用现有 enum | `lowBattery` |

`@2x` 表示同一逻辑尺寸的两倍像素密度，不表示“第二个设计版本”。此包只提供 macOS 的 1x / 2x 变体。[A2]

原始图片保持字节不变，替换前先核对 SHA-256。不要把 1254 像素图片重命名为 `*-1024.png` 就当作调整尺寸。历史候选不使用正在被代码引用的正式资源名。

## 3. 当前资源映射表

| 用途 | 原图相对于 assets-source/ | 实际 asset 名 | 当前状态 |
|---|---|---|---|
| App 主图标 | `app-icon/macsoul-app-icon-source.png` | `MacSoulAppIcon` | 已接入；Owner Dock 单项认可，其他条件按账本保留 |
| 菜单栏 | `menu-bar/macsoul-menu-template-source.png` | `MacSoulMenuTemplateDraft` | 当前使用 Draft；非正式美术全部定稿 |
| 正常 | `soul/soul-normal.png` | `MacSoulNormal` | 透明 PNG，已接入；具体状态/视觉批准见实际报告 |
| 忙碌 | `soul/soul-busy.png` | `MacSoulBusy` | 透明 PNG，已接入；具体状态/视觉批准见实际报告 |
| 脑子过载 | `soul/soul-overload.png` | `MacSoulOverload` | 透明 PNG，已接入；具体状态/视觉批准见实际报告 |
| 胃撑 | `soul/soul-bloated.png` | `MacSoulBloated` | 透明 PNG，已接入；具体状态/视觉批准见实际报告 |
| 低电量 | `soul/soul-low-battery.png` | `MacSoulLowBattery` | 透明 PNG，已接入；具体状态/视觉批准见实际报告 |
| 休息 | `soul/soul-sleeping.png` | `MacSoulSleeping` | 透明 PNG，已接入；具体状态/视觉批准见实际报告 |

预留正式菜单栏名 `MacSoulMenuTemplate`，**本包没有这个 asset**。只有精修与人工小尺寸验收通过后才使用，届时更新调用点、清单和验收证据。

## 4. Soul 的业务状态映射

| 现有状态机结果 | 推荐图片 | 配套文案示例 |
|---|---|---|
| 正常、平静 | `MacSoulNormal` | 今天挺轻松。 |
| 忙碌但未达严重级别 | `MacSoulBusy` | 我在认真干活。 |
| CPU 持续过载 | `MacSoulOverload` | 我的脑子要爆炸了。 |
| 内存压力严重 | `MacSoulBloated` | 我的胃快撑爆了。 |
| 电池不足且未恢复 | `MacSoulLowBattery` | 我真的需要充电了。 |
| 用户设定的休息/空闲表现 | `MacSoulSleeping` | 安静休息一下。 |
| 已确认恢复 | `MacSoulNormal` | 呼……终于安静了。 |

这里不是新的阈值规则。CPU 触发时长、memory pressure、优先级、迟滞、cooldown 和恢复，继续读取当前 `docs/SOUL-ENGINE.md`。不要在 View 中重新按内存已用百分比触发“胃撑”，不要为换图再起一轮采样。电脑真正睡眠时不为动画唤醒采样。

暂无专用断网/AI 额度角色图。可以复用正常形象并改变文案；不要把 `MacSoulLowBattery` 当成 AI 额度不足的固定语义，不扩充状态机来迁就图片。

## 5. 调用规则

下面是调用方式示例，不是要求再建一套状态存储或重复的 enum。

```swift
Image("MacSoulNormal")
    .renderingMode(.original)
    .resizable()
    .scaledToFit()
    .frame(width: 144, height: 144)
    .accessibilityHidden(true) // 仅当旁边已有同义、可访问的状态文字
```

彩色 Soul 使用 original；菜单栏候选才使用 template。Apple 定义 template 模式按非透明区域绘制前景色；仅把彩色 PNG 的像素改成黑白，并不能证明它已经适合菜单栏。[A3]

```swift
// 当前菜单栏使用 Draft；名称不代表正式美术定稿。
Image("MacSoulMenuTemplateDraft")
    .renderingMode(.template)
    .resizable()
    .scaledToFit()
    .frame(width: 18, height: 18)
    .accessibilityLabel("MacSoul")
```

统一通过现有资源映射层/枚举引用，不在多处散落中文文件名。示例映射可用 `normal → "MacSoulNormal"` 等常量，复用已有类型；不要直接从 `assets-source/` 使用绝对文件路径读取运行时图片。

## 6. 尺寸与构图（本项目约定）

- Soul 资源统一使用 256 pt 方形画布，提供 256 px @1x、512 px @2x。
- Overview 建议 112–160 pt；菜单栏 popover 内角色建议 40–56 pt。真正的菜单栏小图标不使用彩色 Soul。
- 状态间固定展示框，使用 `scaledToFit`；不拉伸成椭圆，不用 `scaledToFill` 截掉手、尾巴或周边动作元素。
- 原图六张都是 1254 方形画布，本包未逐图裁边；画面内角色的动作和视觉重心仍有差异。切换效果必须人工确认，不宣称已达到像素级配准。
- 不添加额外大半径发光来叠加源图已有光晕；深浅主题都要检查蓝紫边缘。
- 这些是静态状态图，不是可连续插值的骨骼/序列动画。可选轻微淡入淡出要遵守减少动态效果设置，不为图片常驻运行高频 timer。

## 7. 新图或修订图进入仓库

新增原稿用新版本名归档，发布用 asset 名保持稳定。先更新 `source-provenance.json` 和资源清单，再验收尺寸、alpha、状态映射、深浅色和实际 UI。不得删掉失败检查来保持绿灯。

本包 `asset-manifest.json` 是当前交付快照。之后有意修改文件导致哈希不同是正常的版本变更；必须检查差异和重新生成对应记录，而不是无条件忽略错误。

技术事实来源见 `ASSET-SOURCES.md`；视觉尺寸、名字、映射都是 MacSoul 本包约定，不是 Apple 强制规定。
