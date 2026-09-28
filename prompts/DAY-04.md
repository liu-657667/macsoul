> 一体包前置门禁：先检查 Phase A 与真实任务状态；未完成则返回 `prompts/BOOTSTRAP.md`。
> 此文件保留原日计划，优先服从 `docs/INTEGRATION-NOTES.md` 和迁移后的任务依赖；模型角色是建议，不自动启用旧配置。
> 不重置已有进度；Day 5 以后不新做 Notch。

# Codex Day 4 — Real-time AI quota + Menu Bar polish

Read `AGENTS.md`, `docs/STATUS.md`, `docs/PROGRESS-PROTOCOL.md`, `docs/7-DAY-PLAN.md`, and all feature docs relevant to Day 4.

Before implementing:
1. Check yesterday's completion and carry-over.
2. Apply the catch-up algorithm automatically.
3. If Recovery Mode triggers, update `docs/STATUS.md` before coding and explicitly list scope cuts.
4. Do not re-open completed architecture decisions without evidence of a blocker.

Execute **Day 4 only**. Prioritize carry-over P0, then today's P0, then P1. P2 is allowed only when schedule is GREEN and all P0 acceptance checks pass.

Use subagents intentionally:
- explorer for read-only mapping,
- tester for focused tests,
- reviewer for correctness/privacy/performance review.
Avoid parallel write ownership of the same files.

Before finishing:
- run relevant build/tests,
- perform the day's quality/performance checks,
- update `docs/STATUS.md`,
- write/update `reports/day-4.md`,
- report completion %, schedule state, carry-over, risks, and next day's exact starting point.
