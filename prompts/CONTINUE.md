# 继续当前任务

先读 `AGENTS.md`、`docs/STATUS.md` 和已有 `tasks.json`（如果尚未建立，不虚构其存在）。
Phase A 未完成：继续 `prompts/BOOTSTRAP.md` / Review Phase A，不开启其他功能。
Phase A 已完成：确认用户已允许进入下一阶段，按当前验收账本选择最高优先级、依赖已满足的任务。

优先：构建/运行回归 → 核心阻塞 → 验收 → 当前 ready 任务 → 已批准的可选任务。
不要仅因当前 Day 编号跳过阻塞，不要因为到了某天就自认前一天完成。
保留原始基线；未完成延期可见，不用删项来制造百分比。只推进当前授权的任务范围。
结束时保存真实命令、退出码与证据，分别报告 build/unit/manual UI/performance 和下一项。
