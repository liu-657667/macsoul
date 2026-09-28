# 可选历史配置模板

`codex-family-original/` 原样保存之前 Harness 的 `.codex` 内容，包括 model ID 与 5 个角色配置。
它们**没有被新包的 `.codex/config.toml` 引用**。语法正确不等于你本机支持，不要直接复制启用。
先按 `docs/MODEL-STRATEGY.md` 核验本机实际模型和配置机制，再由你决定是否启用。
尤其不要把 reporter 的文字限制当作 docs-only 文件系统权限。默认一个写者即可。
