# AI Quota Integration — Real-Time Without Aggressive Polling

## User-facing scope
Codex and Claude Code each support 5h and 1-week windows, but the App renders only windows applicable to the current account. A Week-only result produces one numeric Week row, never an invented 5h progress bar. This 2026-09-28 owner revision supersedes the earlier four-values-must-appear rule; dated review reports remain historical.

No Pro / Plus plan-name branch decides which window exists. A future live Provider must use the actual response and verified interface semantics. An omitted field is `unreported` unless that interface explicitly proves the window is `notApplicable`; omission is not unlimited quota.

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

Presentation derives `fresh` or `stale` for each available window from the sample age, Provider freshness and that window's reset time. `notApplicable` has no summary row or progress in Overview and Menu Bar; AI Coding detail may explain it. `unreported`, `requestFailed` and `providerUnavailable` get distinct status rows with no progress. Overview, AI Coding and Menu Bar reuse this same presentation model and `QuotaRow`, with summary and detail variants.
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
- fresh available window: used % (including 0%) and available reset
- stale threshold or reset expiry: last used % marked `Stale`, with last update; no automatic reset to 0%
- not applicable: no numeric row or countdown
- unreported / request failure / Provider unavailable: separate text, no fake 0% or unlimited claim

## Alerts
Optional 95% alerts for 5h/week. 80% may exist but off by default. Deduplicate until the relevant window resets. Alert and Soul eligibility require a fresh, applicable numeric window; absent 5h has no alert or countdown. The Phase A Mock App exposes only eligibility logic and does not send runtime quota notifications.

## Hardening clarifications
Main window and Menu Bar render the applicable independent windows from the same snapshot. Data mode (mock/live), availability and freshness are separate. Reset expiry without a new Provider snapshot must not produce 0%.
A local update notification does not prove immediate cross-client/global visibility; that requires a separate test. Verify installed provider capabilities, response field names, account/bucket mapping and authentication mode before claiming live support.
During Phase A use fixtures only: Codex Week-only, both windows, unreported window, valid 0%, request failure and stale; Claude follows the same rules. Do the read-only capability spike in a later explicitly started work unit. Preserve existing Claude statusline config before any approved bridge installation; never log full payloads.
A fallback UI test passing is not acceptance of live quota retrieval. Record those checks separately.
