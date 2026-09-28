# MacSoul Harness 加固审查包

> 以下是初始化时的审查说明。原 Day 1 包入口已归档到 `docs/archive/bootstrap/`；当前任务状态以根目录 `tasks.json` 和 `docs/STATUS.md` 为准。

本包是审查结果和后续执行输入，不是新的完整 Harness，不包含编译好的 App，不会覆盖你的原包。

- `AUDIT.md`：具体问题、原始路径/行号、建议修法和验收。
- `CODEX-HARDENING-PROMPT.md`：让 Codex/Claude Code 先做 Phase A 的执行提示。
- `tasks.example.json`：结构化任务/证据示例，不是已完成任务。
- `static-checks.json`：本次真正执行的检查和未执行项目。

用法：把文件放到现有 MacSoul 仓库的 `review/` 下，在该仓库启动 Agent，输入：

> 读取 review/AUDIT.md 和 review/CODEX-HARDENING-PROMPT.md，只执行 Phase A。保留现有改动，先修一致性与构建验收，不新增产品功能。

原始 MacSoul 代码与进度尚未被本次审查修改。需在你的 Mac 上实际编译、运行、测量。
