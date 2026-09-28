# 7-Day Progress & Catch-Up Protocol

## Why this exists
The sprint must finish with a releasable v0.1. Falling behind changes scope, not quality gates.

## Daily task classes
- **P0** release-critical / blocks later work
- **P1** important but can be simplified
- **P2** stretch/polish; first to cut

## Daily close requirements
Codex must update `docs/STATUS.md` and `reports/day-N.md` with:
- planned points
- completed points
- completion %
- P0/P1/P2 completed
- incomplete items + reason
- build/test commands and result
- known bugs
- performance/privacy risks
- carry-over
- next-day plan

## Completion scoring
Each task in the 7-day plan has points. Completion % = accepted completed points / planned points for that day. A task only counts when its acceptance check is met.

## Schedule state
- **GREEN** >= 90% and no incomplete P0
- **YELLOW** 70–89% or one incomplete P0
- **RED** <70%, two+ incomplete P0s, or a release-blocking regression

## Automatic catch-up algorithm
At next-day start:
1. Pull unfinished P0 to the top.
2. Preserve tests, failure states, and performance validation.
3. Cut/defer yesterday's P2 immediately.
4. Carry P1 only if it blocks current-day P0; otherwise move it to post-v0.1 backlog.
5. Do not let carry-over consume more than ~40% of the next day's intended capacity without entering Recovery Mode.

## Recovery Mode
Trigger if:
- RED day, or
- two consecutive YELLOW days, or
- carry-over >40% of next-day capacity.

Actions:
1. Freeze all P2.
2. Remove Notch enhancement if not already complete.
3. Reduce Cleaner to scan/explain only.
4. Simplify geo/ASN enrichment; preserve IP/proxy/connectivity basics.
5. For Claude quota, preserve honest `Unavailable` fallback rather than spending the release on brittle reverse engineering.
6. No new visual polish except bug/accessibility fixes.
7. Keep core System/Soul/Menu Bar/Codex quota/Dev/Network functional.

## Scope freeze
End of Day 5. Days 6–7 cannot add new product modules.

## Rule
Never "catch up" by skipping tests, hiding errors, increasing unsafe polling, or inventing data.

## GPT-6 model routing by schedule health

Use `docs/MODEL-STRATEGY.md` as the authority.

- **GREEN:** Sol owns implementation. Luna handles exploration/reporting/mechanical work. Astra appears only at planned architecture/release gates.
- **YELLOW:** Ask Astra once to diagnose the main blocker or validate the catch-up plan, then return implementation to Sol. Do not solve schedule pressure by putting every task on Astra.
- **RED:** Astra high produces/validates the recovery plan and attacks the hardest release-critical blocker. Sol implements. Luna handles repository mapping and progress reporting. Cut P2 before weakening tests, privacy, or performance gates.

Every daily report must include a `Model usage` section listing which roles were used and whether any xhigh/max escalation occurred. If Astra xhigh/max was used, record the release-critical reason.
