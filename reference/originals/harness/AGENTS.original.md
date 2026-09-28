# MacSoul — Agent Operating Contract

## Mission
Ship **MacSoul v0.1 in a 7-day sprint**: a native, local-first macOS developer control center with a restrained personality layer (Soul).

MacSoul answers five questions:
1. Is my Mac healthy?
2. What is consuming resources?
3. What is my developer environment doing?
4. What is my network identity/connectivity?
5. How much **Codex / Claude Code 5h + 1-week quota** remains?

## Mandatory workflow
Before changing code in every session:
1. Read `docs/STATUS.md`.
2. Read `docs/7-DAY-PLAN.md` for the current day.
3. Read relevant feature docs.
4. State the current objective and blocking carry-over items in your internal work plan.
5. Work only on the current day's P0/P1 scope unless `STATUS.md` explicitly permits stretch work.

Before ending every substantial session:
1. Build/test what changed.
2. Update `docs/STATUS.md`.
3. Append/update today's report in `reports/day-N.md`.
4. Record incomplete tasks and classify them P0/P1/P2.
5. If the day is behind, apply `docs/PROGRESS-PROTOCOL.md` automatically.
6. Give the user a concise progress report: completion %, done, not done, tests, risks, carry-over, next action.

## Hard product constraints
- Native macOS app: Swift + SwiftUI; AppKit only when necessary.
- Local-first. No cloud account and no source-code upload.
- No root requirement for v0.1.
- AI Coding is quota-only: Codex + Claude Code, **5h and 1 week only**.
- Never invent quota values. `Unavailable` is valid product behavior.
- Menu Bar is the universal quick surface on every Mac.
- Notch experience is optional enhancement only; never make core functionality depend on it.
- Soul is deterministic/local for v0.1. No LLM dependency.
- Cleaner v0.1 is scan/explain-first; destructive cleanup is limited to clearly safe items with confirmation.
- No new features after Day 5 scope freeze.

## Performance contract
MacSoul must not become the process the user needs to monitor.
- Prefer event-driven updates > native API sampling > cached polling > shell commands.
- No 1-second shell subprocess polling.
- No continuous recursive disk scanning.
- Heavy storage scans are user-initiated.
- One shared sensor snapshot feeds UI + Soul; do not duplicate monitoring per screen.
- Target background average CPU < 0.5% when window is closed; hard review if > 1% sustained.
- Target memory < 100 MB; hard ceiling goal < 150 MB unless justified and documented.

## Engineering rules
- UI never invokes shell/network providers directly.
- Use protocols/adapters around external integrations.
- All recurring work is cancellable and lifecycle-aware.
- Fast/slow/event/on-demand sampling tiers are mandatory.
- Use typed domain models and structured errors.
- No credentials, project source, shell history, or secrets in logs.
- Destructive actions require explicit confirmation.
- Add unit tests for parsers, state machines, threshold transitions, quota mapping, and provider fallbacks.

## Scope discipline
When schedule slips, **do not** respond by skipping tests, performance validation, or failure states. Follow `docs/PROGRESS-PROTOCOL.md` and cut optional scope first.

## Source-of-truth precedence
1. `AGENTS.md`
2. `docs/SCOPE.md`
3. `docs/DESIGN.md`
4. `docs/ARCHITECTURE.md`
5. feature docs
6. `docs/7-DAY-PLAN.md`
7. `docs/STATUS.md` for current execution state

## Definition of done for a task
- Acceptance behavior implemented.
- Build succeeds.
- Relevant tests pass.
- Failure/unavailable state handled.
- Performance impact considered.
- STATUS/report updated.
- No unrelated refactor or scope expansion.
