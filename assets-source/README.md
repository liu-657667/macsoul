# assets-source — 原图与导出证据

本目录用于版本管理、设计对照和重导出，**不进入 App target**。

- `app-icon/`：最新 App 原稿，1254×1254 RGB，含不透明外侧深色背景。
- `menu-bar/`：单独的单色菜单栏原稿，1254×1254 RGBA；细节偏多，待精修。
- `soul/`：六状态 RGBA 原稿，真实透明，原有光晕保留。
- `reference/`：历史候选、细化稿、产品概念海报，只做参考。
- `preview/`：已有图片的排版/深浅背景/原尺寸测试预览，不是新生成的品牌画稿。
- `source-provenance.json`：来源和转换过程。
- `asset-manifest.json`：交付文件哈希与资源契约。
- `packaging-checks.json`：当前环境的静态验证结果，未包含 Xcode 实测。

生产候选派生 PNG 位于 `MacSoul/Resources/MacSoulBrand.xcassets/`，不要让 View 读取此目录中的原始大图。
