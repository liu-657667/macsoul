# AI Quota Integration — Real-Time Without Aggressive Polling

## User-facing scope
Exactly four values per provider:
- 5h used % + reset
- 1-week used % + reset

Providers: Codex and Claude Code.

## Common model
```text
AIQuotaSnapshot
- provider
- fiveHour: QuotaWindow?
- weekly: QuotaWindow?
- sampledAt
- source
- status

QuotaWindow
- usedPercent
- durationMinutes
- resetsAt
```

## Codex
Preferred: official Codex app-server rate-limit facilities.
- Read initial account/rate-limit state on connection.
- Subscribe/use rate-limit update notifications where supported so the UI can update event-first.
- Select windows by duration/semantics, not response order: ~300 min → 5h, ~10080 min → week.
- Reconnect/backoff gracefully.
- A slow fallback refresh may verify stale state; do not hammer the app-server.
- Never read ChatGPT credentials directly.

## Claude Code
Preferred: a stable local/documented mechanism such as status-line data that exposes rate-limit windows, consumed through an isolated local bridge.
- Bridge stores/transmits only 5h/week percentages/reset timestamps + timestamp.
- Do not ingest prompts, source paths, conversation bodies, or credentials.
- If a stable source is unavailable for the installed version, render `Detected · Quota unavailable`.
- Never scrape private credential endpoints to make the UI look complete.

## Freshness UI
Always expose last-updated/source in details.
- fresh event update: normal
- stale threshold exceeded: `Last updated …`
- unavailable: no fake 0%

## Alerts
Optional 95% alerts for 5h/week. 80% may exist but off by default. Deduplicate until the relevant window resets.
