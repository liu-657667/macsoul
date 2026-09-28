# 视觉资源增量接入记录

日期：2026-09-28（Asia/Shanghai）。任务账本：`VA-01`，不计入原七天计划的 76 点。基线提交：`76c95dcecac24d11545c271c20ad9bba0aa7337b`；当前源码/工程/脚本指纹：`258cede7d8bb0e9901a6640f23712940c77750f72f251ec006ac9ad5720a7171`。本轮更改尚未提交或推送。

## 接入范围

- 以原目录结构增量导入品牌 catalog、原图与历史参考、资源规范和静态检查脚本；未覆盖既有 Swift 源码或工程文件，也未导入 `.DS_Store`。
- `MacSoulBrand.xcassets` 由现有 App target 的资源阶段编译；App Icon Source 是候选 `MacSoulAppIcon`。负责人确认生成的视觉资源可用于替换后，`MacSoulMenuTemplateDraft` 已接入 Mock App 的实际菜单栏入口；Debug 设置页仍可按 18 pt 预览。它仍叫 Draft，原生小尺寸视觉效果待验收。
- `SoulVisual` 将六种 Mock 展示状态映射到 `MacSoulNormal`、`MacSoulBusy`、`MacSoulOverload`、`MacSoulBloated`、`MacSoulLowBattery`、`MacSoulSleeping`。Overview 与菜单弹层通过共享 `AppSnapshot` 显示图片和旁边的状态文字。Debug 设置页可切换 fixture；这不新增真实采样或第二套业务状态机。
- Overview 的 Soul 标题已从大脑系统图标改为 `MacSoulMenuTemplateDraft` 品牌小图标；负责人提供的新截图确认大脑图标已移除、六种状态图片正确。
- App 内 `Assets.car` 可查到 8 个资源名；生成的 Info.plist 引用 `MacSoulAppIcon`，Resources 顶层只有 `Assets.car` 和 `MacSoulAppIcon.icns`。`assets-source/`、历史海报、预览和开发文档不在 App 运行时资源内。
- 负责人截图指出 Cleaner 侧栏图标缺失。AppKit 检查 `NSImage(systemSymbolName: "broom", ...)` 返回 nil，`magnifyingglass` 返回图像；侧栏与 Overview 均改用后者，以表达只读查看/扫描。负责人已确认修复后的图标可见。
- 构建包内的 `MacSoulAppIcon.icns` 可解码，Info.plist 也正确引用。macOS 从隐藏的 `.artifacts/DerivedData` 路径读取 App 图标时给出通用占位图；同一包在可见路径能给出品牌图标。新增 `scripts/run-mock.sh`，构建后复制到被 Git 忽略的 `build-preview/` 并启动；脚本检测已有 MacSoul 进程，避免重复菜单栏图标。当前运行进程来自可见路径，`NSWorkspace` 对 App 文件和运行进程都返回品牌图标；负责人截图确认 Dock 图标正常。
- README 已引用仓库内 `assets-source/reference/macsoul-product-hero.png`；下载包与仓库文件 SHA-256 同为 `cc68a29ccc4bff777560708953164f5a0b6693927c583f32800a25b9eb8aa44c`。图片明确标为产品概念图，其实时指标、VPN、服务延迟和清理按钮不代表当前功能。

## 实际验证

| 项目 | 状态 | 命令与证据 |
|---|---|---|
| STATIC | PASS | `python3 scripts/verify-visual-assets.py` 退出 0；59 文件、38 PNG 头、8 asset set；`.artifacts/visual-assets-check.json` |
| BUILD / ACTOOL | PASS | `./scripts/build.sh` 退出 0；当前 Release `xcodebuild ... build` 退出 0；`.artifacts/build.log`、`.artifacts/visual-assets-release-build.log` |
| UNIT | PASS | `./scripts/test.sh` 退出 0；12 个 XCTest、0 失败；`.artifacts/test.log` |
| MANUAL_UI | PARTIAL / OWNER_PENDING | 负责人确认 Cleaner、六种 Soul 图片、Dock 图标与 Soul 标题品牌图标，并回复菜单栏小图标、弹层背景和配额文字“通过，按当前效果验收”。此后新增 Disk/Battery 菜单卡片，新排版仍待负责人查看。 |
| PERFORMANCE | NOT_RUN | 未做 Release、无调试器持续测量 |
| LIVE_PROVIDER | NOT_RUN | 仍为 Mock App |

`./scripts/verify.sh` 再次运行的 doctor/build/unit/progress/static 均 PASS；自动检查的证据已更新到当前指纹。A1/A3 的历史人工界面确认原样保留；当前动态窗口修订改为 verifying，不以旧四窗口截图充当新验收。当前总入口结果见 `.artifacts/verification.json`。

## 仍待验收

- 六种状态图片和 Dock 图标已得到负责人当前界面确认；后续仍可按需要单独检查深色外观。
- 菜单栏 18 pt Draft、白色不透明背景和配额文字已得到负责人确认。最新菜单栏系统指标由 CPU/Memory 扩为 CPU/Memory/Disk/Battery 的 2×2 排列；新增排版尚无负责人界面确认。
- 负责人说明这批图由网页 GPT 生成并允许用于替换当前视觉资源。此授权记录不将图像自动改标为 MIT；本轮不自动推送公开仓库。
