# MacSoul 视觉资源包 · 从这里开始

## 当前资源维护入口 — 2026-10-08

资源已接入公开 v0.1.0，无需按初始 ZIP 流程重新导入。菜单栏当前使用 **MacSoulMenuTemplateDraft**，并非尚未启用，也不代表正式美术全部定稿。Owner 的 Dock 单项认可、其他视觉条件及增量 verifying 见 [历史视觉 closeout](reports/phase-a-visual-closeout-2026-09-28.md)；后续 Menu Bar/Mock/Live 的实际观察与限制见 [FINAL](reports/FINAL.md) 和 [发行说明](docs/RELEASE.md)。不扩展资源来源、许可证或 Owner 美术批准范围。

以下初始导入、候选说明与未勾 checklist 为 **Historical / Initial integration reference**，不是要求重新接入或全面 PASS。


> 公开文本中的 Owner-home 路径前缀已替换为 `<OWNER_HOME>`；命令含义、日期、哈希和历史结果保留。原私有证据与 Git 历史未改写；此项与 distributed App package privacy 分别记录。

版本：0.1 · 整理日期：2026-09-28

这是**现有 macsoul 仓库的增量资源包**，不是第二个项目，也不是新的 Harness。没有修改或打包覆盖你的 AGENTS.md、CLAUDE.md、任务账本、Swift 源码或工程文件。

## Historical — 初始包导入方法

ZIP 内的路径相对于项目根目录，没有多套一个 `macsoul/`。

```bash
cd <OWNER_HOME>/githubWorkspace/macsoul
unzip -n "$HOME/Downloads/MacSoul-Visual-Assets.zip" -d .
python3 scripts/verify-visual-assets.py
```

`unzip -n` 不覆盖已有同名文件。若校验报告某个文件不一致，先检查差异，不要强制覆盖。Finder 手动复制时使用“合并”，不要用整个 `MacSoul` 文件夹替换现有源码目录。

## 包内有什么

| 内容 | 路径 |
|---|---|
| 最新一批 8 张原图：App 1、菜单栏 1、Soul 6 | `assets-source/app-icon/`、`menu-bar/`、`soul/` |
| 历史 4 个候选、选中后的细化稿、产品主视觉 | `assets-source/reference/` |
| 用于接入的图片资源目录：8 个 set、24 张派生 PNG | `MacSoul/Resources/MacSoulBrand.xcassets/` |
| 命名规范 | `docs/ASSETS-NAMING.md` |
| Assets.xcassets / 独立品牌 catalog 规划 | `docs/ASSET-CATALOG-PLAN.md` |
| 给 Codex / Claude Code 的接入任务 | `prompts/INTEGRATE-VISUAL-ASSETS.md` |
| 验收清单 | `docs/ASSETS-ACCEPTANCE.md` |
| 原图尺寸、透明通道、来源与转换记录 | `assets-source/source-provenance.json` |
| 文件哈希和静态检查 | `assets-source/asset-manifest.json`、`packaging-checks.json` |
| 总览、透明图深浅背景、菜单栏小尺寸预览 | `assets-source/preview/` |

所有原图均保留原始字节。原图实际为 **1254 × 1254**，不是因为重命名就变成 1024。App 导出包含真正的 1024 × 1024 文件；Soul 导出为 256 / 512 像素。

## 需要明确的质量边界

- 六张 Soul 原图都检查到真实 alpha 透明通道；预览里的棋盘格不是资源背景。原有蓝紫光晕保留。
- 菜单栏原稿仍包含星环、星点和面部细节。本包只做单色 alpha 模板化与缩放，**没有重新设计成极简标志**。因此叫 `MacSoulMenuTemplateDraft`，初始导入时建议先验收；后来已启用该 Draft，正式精修仍未获全面批准。
- App 原图的圆角底板外还有深色、不透明的展示背景；派生图忠实保留它。可用于开发接入，但 Dock 小尺寸、外侧留白/底色仍待验收，不把多尺寸导出当成最终视觉精修。
- 本包不是 Icon Composer 多层 `.icon` 工程，也没有动效帧、原生 SVG/矢量母稿或 `.icns`。不要把 PNG 改扩展名冒充这些格式。
- 已执行 PNG/JSON/哈希等静态检查；**未运行 Xcode/actool、App、Dock、菜单栏和 Instruments 验收**。

## Historical — 初始接入 Prompt（当前仓库不重复执行）

```text
读取 ASSETS-START-HERE.md 和 prompts/INTEGRATE-VISUAL-ASSETS.md。
在当前已建立的 MacSoul 工程中增量接入资源；若 Phase A 尚未完成，先完成它。
不要重建 Harness，不要重置任务进度，不要覆盖已有 Swift 源码或主 Assets.xcassets。
只接入 App 图标候选、六个 Soul 状态和菜单栏候选预览。
保留 Mock 模式标识，不接真实监控和配额，不新增产品功能。
菜单栏原稿必须经过小尺寸验收；不合格就保留现有图标并报告。
运行现有构建/测试与资源检查，分别汇报静态检查、构建、人工 UI 的实际结果。
```

图片出现在项目文件夹里，不代表已加入 App target。接入工作要检查 target membership、App Icon Source 和实际运行效果，详见目录规划。[A1]

技术来源编号见 `docs/ASSET-SOURCES.md`。本包没有改变项目或视觉资产的许可证；公开发布前由维护者确认视觉资产授权范围。
