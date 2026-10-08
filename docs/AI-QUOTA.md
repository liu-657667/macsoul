# AI Quota Integration — Real-Time Without Aggressive Polling

## Current v0.1.0 contract — 2026-10-08

Published [Unsigned Developer Preview](RELEASE.md): exact Codex CLI **0.160.0 / 0.160.1 / 0.162.0-alpha.2** are verified; unknown versions fail closed. UI text/bars show remaining (`100 - usedPercent`), while canonical fields and alert thresholds retain usedPercent. Live summaries render only applicable/reported windows; Week-only never gets an invented 5h row. Claude remains honestly unavailable without a verified installed live source. Owner Live acceptance is recorded in [Day 7](../reports/day-7-release-closeout-2026-10-07.md); natural quota updates and real quota95% events remain NOT_OBSERVED. The dated Day 4 checkpoints below retain their original UNKNOWN / NOT_RUN and version observations; later acceptance does not backfill them.

## User-facing scope
Codex and Claude Code each support 5h and 1-week windows, but the App renders only windows applicable to the current account. A Week-only result produces one numeric Week row, never an invented 5h progress bar. This 2026-09-28 owner revision supersedes the earlier four-values-must-appear rule; dated review reports remain historical.

No Pro / Plus plan-name branch decides which window exists. A live Provider must use the actual response and verified interface semantics. An omitted field is `unreported` unless that interface explicitly proves the window is `notApplicable`; omission is not unlimited quota.

## Common model
```text
AIQuotaSnapshot
- provider
- fiveHour: QuotaWindowState
- weekly: QuotaWindowState
- sampledAt
- source
- status

QuotaWindowState
- available(QuotaWindow), including valid 0%
- notApplicable (only with explicit Provider semantics)
- unreported (missing/unknown field)
- requestFailed (request attempted and failed)
- providerUnavailable (no live Provider connected)

QuotaWindow
- usedPercent
- durationMinutes
- resetsAt
```

Presentation derives `fresh` or `stale` for each available window from the sample age, Provider freshness and that window's reset time. `notApplicable` has no summary row or progress in Overview and Menu Bar; AI Coding detail may explain it. Preview retains distinct `unreported`, `requestFailed` and `providerUnavailable` rows with no progress. Live summaries omit individual unreported windows (details explain them); if no windows are reported, the provider has a single Not reported message. Errors/unavailable remain explicit. Overview, AI Coding and Menu Bar reuse this same presentation model and `QuotaRow`, with summary and detail variants.
The shared row reevaluates time-based freshness every 60 seconds while visible; this is a UI clock, not a Provider polling schedule.

## Codex
Preferred: official Codex app-server rate-limit facilities.
- Read initial account/rate-limit state on connection.
- Subscribe/use rate-limit update notifications where supported so the UI can update event-first.
- Select windows by duration/semantics, not response order: ~300 min → 5h, ~10080 min → week.
- Treat Week-only as `notApplicable` for 5h only when the validated response semantics establish that fact; otherwise use `unreported`.
- Reconnect/backoff gracefully.
- A slow fallback refresh may verify stale state; do not hammer the app-server.
- Never read ChatGPT credentials directly.

## Claude Code
Preferred: a stable local/documented mechanism such as status-line data that exposes rate-limit windows, consumed through an isolated local bridge.
- Bridge stores/transmits only 5h/week percentages/reset timestamps + timestamp.
- Do not ingest prompts, source paths, conversation bodies, or credentials.
- If a stable source is unavailable for the installed version, render `Detected · Quota unavailable`.
- Claude follows the same dynamic 5h/Week and status rules; do not assume its window set matches Codex.
- Never scrape private credential endpoints to make the UI look complete.

## Freshness UI
Expose last-updated/source and full reset timestamps in AI Coding details. Overview and Menu Bar show short reset hints for fresh values; their relative time is computed from the supplied UI clock. Abnormal states remain explicit in summaries.
- fresh available window: remaining % and available reset; text and progress both use `100 - usedPercent`
- stale threshold or reset expiry: last remaining % marked `Stale`, with last update; never replenish it to 100% without a new Provider snapshot
- not applicable: no numeric row or countdown
- unreported / request failure / Provider unavailable: separate text, no fake 0% or unlimited claim

The protocol and canonical QuotaWindow retain validated `usedPercent` in 0–100. Remaining is presentation only, with no clamping of invalid provider data. A valid consumed 0% displays 100% remaining; consumed 100% displays 0% remaining. Alert/Soul eligibility continues to use canonical `usedPercent >= 95`.

## Alerts
Optional 95% alerts for 5h/week. 80% may exist but off by default. Deduplicate until the relevant window resets. Alert and Soul eligibility require a fresh, applicable numeric window; absent 5h has no alert or countdown. Historically the Phase A Mock App exposed only eligibility logic. Current `QuotaAlertEngine` emits bounded in-memory events for eligible fresh Live windows; it adds no system notification permission/subsystem. Actual natural quota95% events remain NOT_OBSERVED.

## Hardening clarifications
Main window and Menu Bar render the applicable independent windows from the same snapshot. Data mode (mock/live), availability and freshness are separate. Reset expiry without a new Provider snapshot must not produce 0%.
A local update notification does not prove immediate cross-client/global visibility; that requires a separate test. Verify installed provider capabilities, response field names, account/bucket mapping and authentication mode before claiming live support.
Historical Phase A fixture scope: Codex Week-only, both windows, unreported window, valid 0%, request failure and stale; Claude follows the same rules. The later authorized spikes are recorded below and in the Day 7 report; this historical instruction does not authorize a new live read. Preserve existing Claude statusline config before any approved bridge installation; never log full payloads.
A fallback UI test passing is not acceptance of live quota retrieval. Record those checks separately.

## Day 4 first-phase implementation (2026-10-04)

- One AppStore-owned `AIQuotaMonitor` composes Codex and Claude provider instances. Live mode replaces both Mock quotas with source-derived availability; Preview restores the unchanged fixtures. All three surfaces read `AppSnapshot.quotas`; views never start providers.
- The Codex implementation is fail-closed (`approved = false`) pending an explicitly authorized installed-version spike. The candidate documented flow is stdio initialization, one rate-limit read and update notifications. Runtime method support, bucket semantics and cross-client freshness remain UNVERIFIED. No polling fallback is enabled before evidence justifies it.
- Candidate parsing selects the `codex` bucket where present and maps 300/10080-minute durations with a narrow ±1-minute rounding tolerance independently of primary/secondary order, preserving source durations. Other windows remain unreported; broader mapping requires installed-protocol evidence. Missing windows do not prove non-applicability. Percentages must be finite and within 0–100; Unix reset timestamps are retained, never recreated.
- Claude discovery checks only fixed executable locations/PATH and a bounded version command. It does not query authentication or infer it from installation. Official status-line documentation now describes two subscription windows; the pure field parser is groundwork, not an installed bridge. No status-line configuration, transcript access or account query is performed. No installed/verified source means Provider unavailable.
- `QuotaAlertEngine` emits bounded in-memory events for fresh Live values at least 95%, deduplicated by provider/window/reset timestamp. Missing reset identity suppresses announcements conservatively. Preview, unavailable, non-numeric and stale values cannot emit events. Sleep/provider restart retain dedupe history. No notification permission request or new notification subsystem is added; system Soul state/priority remain intact.
- Protocol/unit fixtures and a standalone fake pipe child validate architecture only. Owner Codex Live/UI and real Claude subscription values require separate acceptance. See `../reports/day-4-ai-quota-2026-10-03.md`.

## Day 4 final mapping and integration (2026-10-04)

This checkpoint supersedes the first-phase closed capability gate above, preserving its historical evidence.

- The Owner-approved read-only observation verified bundled Codex CLI **0.160.0**, the initial read, one Codex bucket and a primary **10080-minute** window with no secondary. No real percentage/reset/plan/profile values were retained; notification was not observed during passive 15s listening.
- Native App entry uses only that verified bundled executable after a bounded version check. Other versions fail closed. Injected/default AppStores and XCTest host remain unapproved; fake transport tests never read a real account. Activation requires selecting Live mode; no real App was launched in this checkpoint.
- Bucket selection: identified `codex` key or unique explicit `limitId=codex`, else documented backward-compatible `rateLimits`. Unidentifiable nonempty maps without a valid legacy view fail; map values are never arbitrarily selected or merged. Only the selected bucket's semantics count.
- Unordered primary/secondary use ±1 minute around 300/10080. Unknown valid durations are ignored before checking their unused fields. Recognized duplicates/malformed percentage/reset fail only that window. Valid zero remains numeric; Unix resets are never reconstructed or reset to zero on expiry.
- One serialized fallback read **240s after the previous read completes**, with distinct request IDs and 10s deadline. Update events use the same parser and do not create another read. Stop/sleep/Preview cancel tasks/child; restart awaits teardown and requires a new initial baseline. Automatic failures retain the last numeric snapshot and original sample time, show reconnecting and naturally become stale. Backoff is 1/2/5/10/30/60s capped, reset on a successful read.
- Live Codex numeric data and unavailable Claude coexist in one shared snapshot without Mock fallback. Detail retains source/version and omitted/non-applicable explanation; Live Overview/Menu Bar omit missing 5h rows. Alert/Soul eligibility still requires fresh available numeric windows with a real reset.

### Verified plan semantics and missing 5h

The [0.160.0 rate-limit schema](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/app-server-protocol/schema/json/v2/GetAccountRateLimitsResponse.json) carries optional typed `planType` on the bucket; [official PlanType wire definitions](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/protocol/src/account.rs) define Plus and personal Pro/ProLite/ProMax separately from workspace variants. [Current official pricing policy](https://learn.chatgpt.com/docs/pricing#what-are-the-usage-limits-for-my-plan) states Pro plans currently have no five-hour limit.

Only exact machine enum values `pro`, `prolite`, `promax` collapse to minimal `.pro` semantics; `plus` to `.plus`; all other/malformed/future/UI strings to `.unknown`. No substring, email, user configuration, screenshot, account/read or profile retention. Missing 300 + verified personal Pro = `.notApplicable`; missing 300 + unknown/Plus = `.unreported`. An actual reported 300 always wins, including explicit malformed/requestFailed presentation. No plan is shown in UI or stored in the snapshot.

The prior Owner observation discarded planType; actual Owner machine plan evidence is therefore **UNKNOWN** in the retained observation. Owner/account policy strongly indicates 5h is not applicable, but that retained Provider evidence is insufficient to classify the Owner's account now. A future authorized Live read can apply the implemented rule if it supplies the verified enum; otherwise it stays unreported. No capability spike was rerun.
