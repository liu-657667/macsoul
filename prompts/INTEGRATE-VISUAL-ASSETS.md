# MacSoul 视觉资源接入任务（Codex / Claude Code）

遵循当前会话约束、仓库实际生效的 AGENTS.md / CLAUDE.md 和用户授权。本文件是增量任务，不是替代 Harness。

## 先读并检查

1. 当前 Git 状态、任务账本和 docs/STATUS.md，保留已有代码与未提交改动。
2. ASSETS-START-HERE.md、docs/ASSETS-NAMING.md、docs/ASSET-CATALOG-PLAN.md、docs/ASSETS-ACCEPTANCE.md。
3. 当前工程资源组织、AppStore、Mock 数据契约与 Soul 视图；不要重建这些模块。
4. assets-source/packaging-checks.json 和 preview/ 中的预览。预览不是本机 UI 验收证据。

若工程尚未创建或 Phase A 未通过，先沿现有 prompts/BOOTSTRAP.md 完成 Phase A，再接入资源。不重做七天计划，不启动真实系统/网络/配额接入。

## 本轮范围

- 执行 `python3 scripts/verify-visual-assets.py`；不通过就报告具体文件，不能直接删清单或跳过验证。
- 将 MacSoul/Resources/MacSoulBrand.xcassets 增量关联到现有 App target。
- 保留原 Assets.xcassets、颜色、其他图标及工程文件；若需要合并 catalog，逐个 set 处理且记录原因。
- App Icon Source 接入 `MacSoulAppIcon` 候选，保留其当前外侧背景的已知问题供用户验收。
- 六张 Soul 使用统一 resource-name 映射，在 Overview 和 popover 替换占位角色；数字仍来自现有 Snapshot。
- 使用已有 fixture 选择机制展示六状态。没有该机制时只加一个开发用的场景切换入口，不新增第二套业务状态机。
- 彩色角色 original、等比展示；菜单栏仅 `MacSoulMenuTemplateDraft` 使用 template。
- 菜单栏候选先提供预览/开发选项；不得默认宣称 18 pt 设计已合格。没有人工确认时保留原先工作的菜单栏入口。
- 主窗口与菜单栏中的 Codex/Claude 5h + Week 数据字段都要保持，不因换图片删周额度或重置提示。
- 沿现有质量流程构建、测试；实际打开 App 检查图像路径和布局。没有 Mac 环境或运行权限就相应记录 NOT_RUN。

## 约束

不要调用新图片生成来悄悄替换已选形象；本轮不精修角色、不重画菜单栏、不生成额外动效。
不新增真实采样、OAuth/配额读取、上传数据、Notch 或清理删除。
不升级部署系统/工具链，不修改全局 CLI/Xcode 配置，不自动推送/发版。
不要把 assets-source/ 或海报目录添加为 App 运行时资源。
不要把所有原图每秒重新加载；复用当前视图和资源加载机制。
图片授权不是本轮变更内容，不覆盖 LICENSE。

## 停止与汇报

仅完成当前资源接入和验证后停止，不继续下一个产品里程碑。
根据实际任务账本更新本次任务，不能用“文件已经存在”计为“功能已验收”。
最终用实际证据报告：
- 接入了哪些资源、asset 名称、改了哪些路径/target 设置。
- 哪些是 Draft、Mock、仍待美术调整或人工审批。
- STATIC / BUILD / UNIT / MANUAL_UI / PERFORMANCE 的独立状态。
- 执行命令、退出码、revision/工作树指纹、证据路径。
- 对现有计划的影响和下一步；未知模型/运行环境信息标 UNKNOWN。
