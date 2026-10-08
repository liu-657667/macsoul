# 模型与角色策略 — 不绑死具体版本

本包保留之前讨论的三层分工：主开发、难题/审查、明确边界的辅助工作。
**产品计划不随聊天界面模型名称重写。实际可用模型、model ID、effort、子 Agent 支持都在你本机核验。**

## 建议路由

| 工作 | 角色 | 原讨论中的名称，仅在本机可用时使用 |
|---|---|---|
| 日常 Swift/SwiftUI、集成和普通修复 | 主开发 | Sol / high |
| 重要设计、并发/生命周期难题、发布审查 | 按需审查/难题分析 | Astra / high |
| 小范围查找、整理文档、机械任务 | 可选辅助 | Luna，按实际支持选择档位 |
| 进度百分比、清单和验证结果汇总 | 脚本 | 不需要额外模型 |

此表保留你的偏好，不是本次对三种模型已在你账户可用的证明，也不是实测耗额/性能结论。
Claude Code 用其自身可用模型承担相同角色，不照抄 Codex model ID。

## 仓库配置与历史建议

2026-10-08 用 `git ls-files .codex/config.toml` 确认：仓库未跟踪该文件。个人机器可能有本地配置，但不能写成所有克隆都具备的仓库默认。初始合并包建议 `approval_policy = "on-request"` / `sandbox_mode = "workspace-write"`，仅为历史建议；当前实际权限以会话生效设置为准。
本文不创建配置、不强制 model/effort、不启用并行 agent、不更改 sandbox / approval 或全局设置。
旧文件在 `templates/codex-family-original/`；不要未经核验直接复制回活动配置。

## 本机核验

记录客户端/版本、实际模型选项、选择值、项目配置是否加载、权限边界。
看不到的字段填 UNKNOWN；不从订阅名字或 ChatGPT 当前模型推导 API/CLI ID。
需要改项目配置时先展示差异；不要自动升级工具、改全局配置、申请更高权限或换付费通道。

## 默认执行方式

一个写者，必要时一个只读 Reviewer。测试文件修改顺序进行。
有明确隔离收益时才用 worktree 并行，指定文件范围，合并后重新验收。
Reporter 只读总结，主 Agent / 脚本写账本；提示词中的 docs-only 不是文件系统硬权限。
复杂 blocker 要带错误、复现和失败尝试才升级模型；不能因为排程 RED 就全员最高档。

## 公开参考与边界

核对日期：2026-09-28。本次仅核对基础配置项与指令共享方式，没有查询用户账户或验证本机模型。
- Codex configuration: https://developers.openai.com/codex/config-reference/
- Claude project instructions/import: https://code.claude.com/docs/en/memory
这些文档仍需开发时与安装版本对照。原模型配置和迁移历史作为档案保留，不作为当前可用性保证。
