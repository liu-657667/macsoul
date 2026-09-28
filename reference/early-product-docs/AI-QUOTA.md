# AI Quota Integration

## Product scope
MacSoul's AI Coding feature answers only:
- Codex 5h usage/reset
- Codex 1-week usage/reset
- Claude Code 5h usage/reset
- Claude Code 1-week usage/reset

No token, cost, context, model-performance, or session analytics.

## Shared model
```text
AIProvider = codex | claude

AIQuotaSnapshot
- provider
- fiveHour: QuotaWindow?
- weekly: QuotaWindow?
- sampledAt
- sourceLabel
- status

QuotaWindow
- usedPercent (0...100)
- resetsAt
- windowDuration
```

Provider adapters must select user-facing windows by duration/semantics, not by assuming a hard-coded response order.

## Codex strategy
### Preferred integration
Use the official Codex app-server account/rate-limit API when available. Its rate-limit response exposes buckets containing usage percentage, window duration, reset timestamp, and potentially multiple rate-limit IDs.

Implementation requirements:
1. Keep app-server process/transport logic isolated in `CodexQuotaProvider`.
2. Read rate-limit buckets.
3. Identify the 5-hour and ~1-week windows by `windowDurationMins` (allow reasonable exact-duration matching, not positional assumptions).
4. Convert reset timestamps safely.
5. Ignore unrelated buckets.
6. If either target window is absent, that window is `Unavailable`; do not invent one.
7. Do not read ChatGPT credentials directly from disk.

### Fallback
A future fallback may parse a documented CLI output only if it can be invoked safely and reliably. Do not automate an interactive terminal UI as the primary design.

## Claude Code strategy
Anthropic exposes interactive usage information to Claude Code users, but MacSoul must not depend on reverse-engineering private auth endpoints.

Implementation plan:
1. Create `ClaudeQuotaProvider` protocol implementation with a clearly separated data-source adapter.
2. During the MVP integration spike, check the installed Claude Code version for a stable documented local/programmatic source that contains both 5h and weekly windows.
3. If a supported status-line/command output can be consumed without credentials and with a stable schema, implement it behind a parser with fixtures.
4. If not, ship Claude as `Detected · Quota unavailable` rather than scraping private endpoints.
5. Never read or exfiltrate Claude credentials.

This is an intentional product-quality rule: unsupported is preferable to brittle credential scraping.

## Detection
Provider detection is separate from quota availability.
Possible UI states:
- Not installed
- Installed · quota available
- Installed · quota unavailable
- Error · last successful update timestamp

## Refresh
Default active refresh: 60 seconds. Back off when main UI is closed. A manual refresh action should be available.

## Alerts
Optional thresholds per window:
- 80% (off by default)
- 95% (on by default if notifications are enabled)

Deduplicate alerts until the window resets or drops below the threshold due to a reset.

## Tests
Use captured/synthetic fixtures; never require an authenticated real account in CI.
Test:
- one bucket
- multiple buckets
- missing 5h
- missing weekly
- percentages 0/100
- stale/reset timestamps
- malformed response
- provider executable missing
