# MacSoul 视觉资源 · 技术来源与原稿说明

整理日期：2026-09-28。以下官方资料用于核对资源格式与渲染语义，不代表本包已通过 Xcode 或商店验收。Apple 的部分格式参考是归档文档；具体项目以本机 Xcode 编译结果验证。

## 官方技术资料

[A1] Apple — Configuring your app icon using an asset catalog
https://developer.apple.com/documentation/xcode/configuring-your-app-icon

[A2] Apple — Asset Catalog Format Reference / Image Set Type
https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/ImageSetType.html

用于核对 `.imageset`、命名资源、`Contents.json`、scale 和 template/original 属性。

[A3] Apple — SwiftUI Image.renderingMode(_:)
https://developer.apple.com/documentation/swiftui/image/renderingmode(_:)

用于核对 original 与 template 渲染区别。template 不是自动美术简化功能。

[A4] Apple — Asset Catalog Format Reference / App Icon Type
https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/AppIconType.html

用于核对 `.appiconset`、size、scale、idiom 和图标槽位。

[A5] Apple — Providing images for different appearances
https://developer.apple.com/documentation/uikit/providing-images-for-different-appearances

用于背景：图片应检查浅深外观，template 定义形状而不绑定原始颜色。

## 原稿来源

本包的 8 张主要原图来自当前会话最后一批：App 图标、单色菜单栏原稿、正常、忙碌、脑子过载、胃撑、低电量、休息。原文件均为 1254×1254 PNG。源文件身份、SHA-256、透明比例和派生资源对应关系保存在 `assets-source/source-provenance.json`。

另保留当前会话的 4 个早期候选、选中后细化稿和 1 张产品主视觉，归档到 `assets-source/reference/`。这些不参与运行时资源生成，不会改变已选定方向。产品海报是概念表达，海报中的数值和按钮不是验收过的产品功能。

没有把同名 imagegen.png 当作唯一文件：8 张主要原稿按各自独立文件身份取得并校验，避免下载同名覆盖后遗漏状态。

## 导出做了什么 / 没做什么

做了：原图归档、尺寸导出、PNG alpha 保留、单色候选的 alpha 模板化、Contents.json、命名、预览和静态校验。

没做：重新生成图像、矢量重绘、光晕重修、小尺寸专门重画、Icon Composer 分层、App 集成/构建/运行、品牌或版权可注册性认定。

原图保持原字节；派生图统一按 sRGB 假设附加配置，不是经测量证明原图来自某个色域。没有打包字体文件。

## 许可

本包不新增或修改项目许可证，也不擅自为视觉图案添加“所有权保留”或“MIT”声明。代码许可与视觉资产范围按维护者最终决定在仓库中明确；不要把历史第三方品牌标志或概念图中的工具标志作为自有 Logo 再授权。
