# MacSoul · Assets.xcassets 目录规划 v0.1

## 1. 为什么本包使用独立 MacSoulBrand.xcassets

你可能已经让 Codex 创建了主 `Assets.xcassets`。为避免覆盖它及其颜色、图标或 `Contents.json`，本包选择新增：

```text
MacSoul/Resources/MacSoulBrand.xcassets/
```

它和 `Assets.xcassets` 都是 `.xcassets` 资源目录；品牌资源单独维护是本项目的组织选择。多个 catalog 中的 asset 仍要避免重名，不能靠不同文件夹名掩盖相同资源名。

## 2. 增量落地目录

```text
macsoul/                              ← 你已有的仓库，不重建
├── AGENTS.md                         ← 不改
├── CLAUDE.md                         ← 不改
├── MacSoul/
│   ├── App/                          ← 现有代码，不覆盖
│   ├── ...
│   ├── Assets.xcassets/              ← 若已存在，原样保留
│   └── Resources/
│       └── MacSoulBrand.xcassets/
│           ├── Contents.json
│           ├── MacSoulAppIcon.appiconset/
│           ├── MacSoulMenuTemplateDraft.imageset/
│           ├── MacSoulNormal.imageset/
│           ├── MacSoulBusy.imageset/
│           ├── MacSoulOverload.imageset/
│           ├── MacSoulBloated.imageset/
│           ├── MacSoulLowBattery.imageset/
│           └── MacSoulSleeping.imageset/
├── assets-source/                    ← 不加入 App target
│   ├── app-icon/
│   ├── menu-bar/
│   ├── soul/
│   ├── reference/                    ← 历史候选与产品海报
│   ├── preview/                      ← 校验用合成预览
│   ├── source-provenance.json
│   ├── asset-manifest.json
│   └── packaging-checks.json
├── docs/
│   ├── ASSETS-NAMING.md
│   ├── ASSET-CATALOG-PLAN.md
│   ├── ASSETS-ACCEPTANCE.md
│   └── ASSET-SOURCES.md
├── prompts/INTEGRATE-VISUAL-ASSETS.md
├── scripts/verify-visual-assets.py
└── ASSETS-START-HERE.md
```

只让运行时 catalog 参与资源编译。`assets-source/`、海报、原图、预览、文档与脚本不应被复制进 `.app`。

## 3. App 主图标

本包已生成 `MacSoulAppIcon.appiconset` 和 10 个 PNG 槽位。点与像素分开记录：[A4]

| 点尺寸 | @1x 文件 / 像素 | @2x 文件 / 像素 |
|---|---|---|
| 16 pt | `icon_16x16.png` / 16 | `icon_16x16@2x.png` / 32 |
| 32 pt | `icon_32x32.png` / 32 | `icon_32x32@2x.png` / 64 |
| 128 pt | `icon_128x128.png` / 128 | `icon_128x128@2x.png` / 256 |
| 256 pt | `icon_256x256.png` / 256 | `icon_256x256@2x.png` / 512 |
| 512 pt | `icon_512x512.png` / 512 | `icon_512x512@2x.png` / 1024 |

以上像素均为正方形边长，不是宽高两个不同值。`Contents.json` 已填写 `idiom: mac`、`size`、`scale` 与 `filename`，每个引用都对应实际文件。

工程接入时，把目标的 App Icon Source 设为 **MacSoulAppIcon**，验证对应 catalog 属于 App target。不要同时随意修改多套 Info.plist 图标配置，优先遵循现有工程的 asset catalog 路线。[A1]

原稿仍是带不透明外侧深色展示背景的平面 PNG。没有自动抠掉外侧背景、重画小尺寸或生成 Icon Composer 图层。若 Dock 中显得有黑框/过大留白，要独立精修原稿后再导出；不能改名“Final”就算通过。

## 4. Soul Image Set

六个 set 的格式相同，例如：

```text
MacSoulNormal.imageset/
├── Contents.json
├── soul-normal.png       # 256 × 256 px；1x
└── soul-normal@2x.png     # 512 × 512 px；2x
```

```json
{
  "images": [
    { "idiom": "mac", "filename": "soul-normal.png", "scale": "1x" },
    { "idiom": "mac", "filename": "soul-normal@2x.png", "scale": "2x" }
  ],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "template-rendering-intent": "original" }
}
```

Image Set 通过名称加载，内部变体提供相应 scale；不要把 `.imageset` 路径或 PNG 文件名当资源名称。[A2]

源图没有内嵌 ICC 色彩配置。派生图按 sRGB 假设标记，原图字节不变；不是凭空推断原图为 Display P3，也没有进行艺术性调色。透明图用预乘 alpha 方式重采样，避免直接对带透明 RGB 的图做不当缩放。

## 5. 菜单栏候选

```text
MacSoulMenuTemplateDraft.imageset/
├── Contents.json
├── macsoul-menu-template-draft.png       # 18 × 18 px
└── macsoul-menu-template-draft@2x.png     # 36 × 36 px
```

这是本项目建议的 18 pt 画布，不是宣称所有 macOS 菜单栏必须用这个尺寸。处理过程：单独的白色原稿 → 保留其 alpha 形状 → RGB 归零为黑 → 裁去主体以外极淡散点并等比例留边 → 输出 1x/2x。**不是把彩色 App 图标缩小**。

`Contents.json` 设置 `template-rendering-intent: template`。SwiftUI 预览使用 `.renderingMode(.template)`；AppKit 代码使用模板图语义而不硬编码“深色必须白图、浅色必须黑图”。template 模式的具体定义见 [A2][A3]。

本包保留 `Draft` 后缀是因为星环、星点和五官在 18 pt 下仍偏复杂。先放进可切换的候选预览；用户确认清楚后，再替换已有菜单栏入口。没有通过就保留当前稳定的系统符号或占位图，不阻塞其余 UI 接入，也不伪报正式 icon 完成。

## 6. 已有 Assets.xcassets 时的两种接入方式

**默认：保留独立 catalog。** 将 `MacSoulBrand.xcassets` 关联到目标，保留原 `Assets.xcassets` 和现有设置，只有 App Icon Source 按批准修改。

**项目强制单一 catalog 时：** 逐个移动 8 个 `.imageset` / `.appiconset` 子目录（实际为 7 个 imageset + 1 个 appiconset）到现有 catalog，先检查重名。不要用整个资源目录覆盖旧目录。移动完成后，源目录不应继续参与构建，否则会有重复资源风险；相应更新本包校验脚本/清单路径并记录迁移。

不创建 `.xcodeproj` 的第二份副本；不为了放图片提高最低 macOS 版本；不添加图片处理运行时依赖。实际编译用当前工程的构建入口执行。[A1]

## 7. 运行时资源开销

现有 UI 按状态加载当前图片，不在每个 CPU 刷新 tick 读磁盘或重新构造 NSImage；不要把所有 1254 原图、历史候选和海报加载进内存。

六张 512×512、4 字节/像素的未压缩图像像素合计约 6 MiB，这是简单像素存储估算，不是实测 App 内存。实际解码、缓存、GPU 与视图开销要在 Mac 上测量，不能用 ZIP 大小推断常驻内存。

## 8. 交付状态

图片尺寸与资源引用已做静态检查。target membership、actool 构建、运行时资源查找、Dock 和浅深菜单栏、VoiceOver、性能均需要本机验证。目录结构正确不等于这些验证已通过。

来源见 `ASSET-SOURCES.md`。
