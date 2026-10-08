# 一体包合并说明与冲突裁决

## Current maintenance entry — 2026-10-08

v0.1.0 已公开发布为 UNSIGNED / UNNOTARIZED Pre-release。当前入口见 [README](../README.md)、[发行状态](RELEASE.md)、[继续维护](../prompts/CONTINUE.md) 与 [最终报告导航](../reports/FINAL.md)。原七天计划 48 项 done、76/76；全账本 59 项中 51 done、8 verifying，后者保留历史增量验收状态，不自动重开 Day 7。以当前 Owner 授权决定工作范围。

## Historical — initial All-in-One integration reference

以下记录属于初始合并与 Phase A 检查点，包括当时的“当前状态”，不覆盖后续接受、仓库集成和公开发行。持续有效的语义与权限规则仍保留。

> 后续负责人修正（2026-09-28）：AI 配额窗口按账户实际适用情况动态展示；本页关于双窗口的原始合并记录仅作历史背景。当前规范见 `docs/DESIGN.md` 与 `docs/AI-QUOTA.md`。

版本：All-in-One 1.0 / 2026-09-28。仅对交付文件做整理，不代表你的本地仓库已经变更。

## 合并来源

1. `MacSoul-GPT6-Family-Harness.zip`：主 Harness 全部文件；模型配置移到非活动模板。
2. `MacSoul-Day1-Starter.zip`：16 个 Swift 源文件原样保留；同名 README 归档，启动和设计入口统一。
3. `MacSoul-Harness-Review.zip`：5 个文件完整、字节不变地放到 `review/`。
4. `MacSoul-Agent-Starter.zip`：最早 docs 完整保存到 `reference/early-product-docs/`，不作为第二套活动规则。
5. 之前生成的效果图：放在 reference，仅作视觉参考。

## 本次已做（不是 App 功能完成）

- 扁平化目录：`AGENTS.md` 在根目录；源码在 `MacSoul/`；Review 在 `review/`。
- 根 README/START-HERE 只指向一个启动 Prompt。
- 第一轮默认只做 Phase A，阻止旧 Day 1 Prompt 绕过加固。
- Menu Bar 设计统一为两家各 5h + Week；来源缺失不等于 0%。
- 不在冻结后新做 Notch，不让 Cleaner 删除进入首次执行。
- 移除活动配置中强制模型和未经本机验证的子 Agent 设置；原配置保留为模板。
- 明确初始状态 NOT_STARTED，不假报 GREEN、build pass 或任务完成。
- review 中的历史静态检查与本包内容检查分开；两者都不是本机验证。

## Phase A 当前状态

- Phase A 已创建 Xcode 工程、共享 scheme、测试 target 和固定 build/test/verify 入口；当前结果见 `reports/phase-a.md`。
- Phase A 已实现 SwiftUI 数字同源、窗口独立可空、稳定 ID、Snapshot/Provider 数据契约；人工 UI 验收待负责人确认。
- Menu Bar Swift 代码已补 Week 行；菜单栏弹出层人工验收待负责人确认。
- `tasks.json` 已迁入 76 点原计划与 A1–A4。2026-09-28 已创建 Git 仓库并将 Phase A 起点推送至 GitHub `main`；验证证据仍用工作树 SHA-256 指纹绑定，跨克隆须重跑。实测 build/unit 已记录；人工 UI 尚未验收。

原始源码已按 Phase A 增量修改；以当前构建、测试与人工验收证据判断结果，不能仅因文档要求已修正就声称代码已修复。

## 当前规范优先级

遵守实际系统/开发者/用户指令和权限。仓库内：AGENTS → 本合并说明 → SCOPE/DESIGN → 专题文档。
本合并说明只裁决已发现的文档冲突，不擅自批准减掉核心需求。
旧七天点数基线暂保留，Phase A 报告原始与修订计划；不得将 review/tasks.example.json 当成完整迁移。
review/AUDIT.md 为历史发现清单，templates/reference 为非活动参考。

## 必须坚持的语义

- AI 模块只含配额；降级 UI 完成不等于真实集成完成。
- reset 到时只过期，未刷新不自行清零。跨客户端“实时”必须独立验证。
- 内存压力优先于占用比例；网络 hint 不等于路由证明；监听端口不等于冲突。
- 仅扫描到目录大小，不等于安全可释放空间；不自行判定整个 Maven 仓库可删除。
- 初始合并包中的所有截图/数值都是概念或 Mock；实际版本、账户能力、模型/effort 以本机验证为准。
- 技术优先级、7 天时间预算需如实重估，不能靠删任务或降低质量制造追回进度。
