# assets-source — 原图与导出证据

## 当前资源维护入口 — 2026-10-08

资源已接入公开 v0.1.0，无需按初始 ZIP 流程重新导入。菜单栏当前使用 **MacSoulMenuTemplateDraft**，并非尚未启用，也不代表正式美术全部定稿。Owner 的 Dock 单项认可、其他视觉条件及增量 verifying 见 [历史视觉 closeout](../reports/phase-a-visual-closeout-2026-09-28.md)；后续 Menu Bar/Mock/Live 的实际观察与限制见 [FINAL](../reports/FINAL.md) 和 [发行说明](../docs/RELEASE.md)。不扩展资源来源、许可证或 Owner 美术批准范围。

以下初始导入、候选说明与未勾 checklist 为 **Historical / Initial integration reference**，不是要求重新接入或全面 PASS。


本目录用于版本管理、设计对照和重导出，**不进入 App target**。

- `app-icon/`：最新 App 原稿，1254×1254 RGB，含不透明外侧深色背景。
- `menu-bar/`：单独的单色菜单栏原稿，1254×1254 RGBA；细节偏多，待精修。
- `soul/`：六状态 RGBA 原稿，真实透明，原有光晕保留。
- `reference/`：历史候选、细化稿、产品概念海报，只做参考。
- `preview/`：已有图片的排版/深浅背景/原尺寸测试预览，不是新生成的品牌画稿。
- `source-provenance.json`：来源和转换过程。
- `asset-manifest.json`：交付文件哈希与资源契约。
- `packaging-checks.json`：初始资源包环境的历史静态验证结果，未包含 Xcode 实测。

生产候选派生 PNG 位于 `MacSoul/Resources/MacSoulBrand.xcassets/`，不要让 View 读取此目录中的原始大图。
