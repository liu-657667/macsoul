# MacSoul GPT-6 Model Strategy

Updated: 2026-09-23

MacSoul uses the GPT-6 family by task shape rather than putting the strongest model on every operation.

## 1. Routing principle

| Model | MacSoul role | Default effort | Use it for |
|---|---|---:|---|
| GPT-6 Astra | Escalation / architecture / release gate | high | ambiguous architecture, hard concurrency/lifecycle bugs, difficult provider integration, recovery planning, final review |
| GPT-6 Sol | Primary implementation model | high | normal Swift/SwiftUI implementation, integration, refactors, system/network/dev/quota features |
| GPT-6 Luna | High-volume focused worker | medium | exploration, repository mapping, progress reports, docs, mechanical edits, repetitive scoped work |

Official positioning at generation time: Astra is the highest-capability model, Sol is built for complex coding and agentic workflows / everyday judgment work, and Luna is optimized for focused high-volume work.

## 2. Project default

`.codex/config.toml` deliberately defaults the main coding session to:

```toml
model = "gpt-6-sol"
model_reasoning_effort = "high"
```

Why Sol instead of Astra as the permanent default:
- this is a seven-day sustained coding sprint;
- most tasks are concrete implementation after the design is locked;
- Sol is explicitly designed for complex coding and agentic workflows;
- Astra should remain available as a quality/escalation layer rather than being spent on every routine edit.

If usage limits are not a concern and maximum quality is preferred over throughput, the owner may run the main session on Astra. The task routing below still applies.

## 3. Subagents

### `architect` — Astra / high / read-only
Use before code when:
- the design is ambiguous;
- a decision affects multiple modules;
- a system API approach is uncertain;
- progress is RED and a recovery plan is required;
- a hard blocker has survived one serious Sol attempt.

### `explorer` — Luna / medium / read-only
Use for:
- finding files and symbols;
- mapping existing execution paths;
- identifying tests and dependencies;
- checking whether a planned abstraction already exists.

### `tester` — Sol / medium / workspace-write
Use for:
- unit/integration tests;
- fixtures;
- reproducible validation;
- failure-state testing.

### `reviewer` — Astra / high / read-only
Use at quality gates, especially Day 5–7. It is not a second implementation agent.

### `reporter` — Luna / medium / docs-only by instruction
Use at the end of every workday to update `docs/STATUS.md` and `reports/day-N.md` from evidence.

## 4. Escalation ladder

Do not escalate merely because a task feels annoying.

1. **Luna medium** — understand or perform a tightly-scoped repetitive task.
2. **Sol medium/high** — implement and debug normal product work.
3. **Astra high** — ambiguous architecture, non-local bugs, or high-risk review.
4. **Astra xhigh** — only after evidence is gathered and high has not resolved a release-critical blocker.
5. **Astra max** — exceptional release-blocking problem only. Record why it was required in the daily report.

## 5. Daily model plan

### Day 1 — design lock + native skeleton
- Main: **Sol high**
- Architecture/design challenge: **Astra high architect**
- Repo/docs exploration: **Luna medium**
- End-of-day review: **Astra high reviewer** if architecture materially changed

### Day 2 — System + Soul
- Main: **Sol high**
- Explorer: **Luna medium**
- Tests: **Sol medium**
- Escalate native API/concurrency ambiguity to **Astra high**

### Day 3 — Dev + Network
- Main: **Sol high**
- Shell/runtime/provider mapping: **Luna medium explorer**
- Tests: **Sol medium**
- Astra only for lifecycle/security/design ambiguity

### Day 4 — AI quota
- Main: **Sol high**
- Codex/Claude integration ambiguity: **Astra high architect**
- Fixtures/parsers/docs: **Luna medium** or **Sol medium tester**
- Never fabricate quota data to satisfy the UI

### Day 5 — Cleaner Lite + performance
- Main: **Sol high**
- Repetitive cache-category work: **Luna medium**
- Performance/unsafe deletion review: **Astra high reviewer**
- Scope freezes at end of day

### Day 6 — release candidate
- Main fixes: **Sol high**
- Full release audit: **Astra high reviewer**
- Regression matrix/docs/reporting: **Luna medium**
- Astra xhigh only for release blockers

### Day 7 — ship
- Main: **Sol high**
- Docs/release notes/checklists: **Luna medium**
- Astra high only for final high-risk review or unresolved blocker
- No speculative max-effort feature work

## 6. Progress-aware routing

### GREEN
Use Sol for implementation and Luna aggressively for focused support work. Astra only at planned gates.

### YELLOW
Do not increase every task to Astra. Use Astra once to diagnose the blocker or validate the recovery plan, then return implementation to Sol.

### RED
Invoke Astra high for recovery planning and the hardest blocker. Cut P2 scope first. Sol executes the recovery plan. Luna handles exploration/reporting so the main context stays clean.

## 7. Context discipline

Model strength does not justify loading every document on every turn.
- `AGENTS.md` stays short.
- Read only feature-specific docs for the current task.
- Prefer subagents for bounded exploration.
- Keep daily status in files instead of repeatedly restating the whole project history.
- Do not ask three agents to independently read the entire repository.

## 8. Official references

Generated against OpenAI documentation available on 2026-09-23:
- https://developers.openai.com/api/docs/models
- https://developers.openai.com/api/docs/guides/model-selection
- https://developers.openai.com/api/docs/guides/latest-model
- https://developers.openai.com/api/docs/models/gpt-6-astra
- https://developers.openai.com/api/docs/models/gpt-6-sol
- https://developers.openai.com/api/docs/models/gpt-6-luna
- https://developers.openai.com/docs/config-file/config-reference

If Codex exposes different model availability for the active subscription/account, preserve the **role strategy** and select the closest available model rather than blocking the sprint.
