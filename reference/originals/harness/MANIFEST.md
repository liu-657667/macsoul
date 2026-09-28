# Harness Manifest

## Agent entrypoints
- `AGENTS.md` — hard rules for Codex and other coding agents
- `CLAUDE.md` — Claude Code redirect to the same contract
- `START-HERE.md` — human/operator quick start

## Codex configuration
- `.codex/config.toml` — Sol/high main defaults + GPT-6 family subagent routing
- `.codex/agents/architect.toml` — Astra read-only architecture/hard-blocker advisor
- `.codex/agents/explorer.toml` — Luna read-only mapping agent
- `.codex/agents/reviewer.toml` — Astra read-only release reviewer
- `.codex/agents/tester.toml` — Sol test worker
- `.codex/agents/reporter.toml` — Luna daily progress reporter

## Product/engineering source of truth
- `docs/SCOPE.md`
- `docs/DESIGN.md`
- `docs/ARCHITECTURE.md`
- `docs/SOUL-ENGINE.md`
- `docs/AI-QUOTA.md`
- `docs/PERFORMANCE.md`
- `docs/QUALITY-GATES.md`

## Sprint control
- `docs/7-DAY-PLAN.md` — daily tasks/points
- `docs/PROGRESS-PROTOCOL.md` — catch-up/recovery rules
- `docs/MODEL-STRATEGY.md` — GPT-6 Astra/Sol/Luna routing guidance
- `docs/GPT6-FAMILY-MIGRATION.md` — what changed from the prior harness
- `docs/STATUS.md` — single current execution state
- `reports/` — mandatory daily reports

## Prompts
- `prompts/KICKOFF.md`
- `prompts/DAY-02.md` … `DAY-07.md`
- `prompts/CONTINUE.md`
- `prompts/RECOVERY.md`
- `prompts/DAILY-REVIEW.md`
