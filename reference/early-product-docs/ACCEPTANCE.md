# MVP Acceptance Criteria

## A. App shell
- App launches without root privileges.
- Menu-bar item opens a popover.
- Main window opens from popover.
- Overview/System/Network/AI Coding/Dev/Settings navigation works.
- App remains usable in light and dark appearance.

## B. System
### CPU
- Displays aggregate CPU usage and sampled timestamp.
- Sustained high CPU can transition Soul state according to `SOUL-ENGINE.md`.
- A one-sample spike does not create a critical Soul event.

### Memory
- Displays used/total memory and memory-pressure state when supported.
- Critical pressure triggers at most one Soul event within cooldown.
- Recovery can create one recovery event.

### Disk
- Displays system-volume total/free/used.
- >=95% used produces storage-full state without repeated notifications.

### Battery
- Displays percentage and charging state on supported Macs.
- Desktop/no-battery machines render `Not available` without error.

### Processes
- Top CPU/memory process data does not block the main thread.
- Permission/provider failure is contained to the process section.

## C. Network
- Public IP can be refreshed manually.
- Provider failure shows unavailable/stale state, not an empty fake value.
- Environment/system proxies are visually distinguished.
- Offline mode does not break System or Dev pages.
- Connectivity timeout is worded as a local probe failure.

## D. Dev environment
- Java/Node/Python/Go each render installed version/path or `Not detected`.
- Runtime commands have timeout and caching.
- Listening ports show port + owning PID/process when available.
- Terminate process asks for confirmation.
- Force kill is a distinct explicit action.

## E. AI quota
### Codex
- If official app-server quota data contains a 5h bucket, it is displayed with percent/reset.
- If it contains a weekly bucket, it is displayed with percent/reset.
- Missing bucket displays `Unavailable`.
- No credential files are parsed directly.

### Claude
- Provider install detection works independently of quota availability.
- Only a documented/stable local/programmatic source may populate quota.
- If unavailable, UI explicitly states `Quota unavailable`.

### Common
- No quota value is guessed.
- 5h/week are the only user-facing windows.
- Last-updated and source are available in details.

## F. Soul
- Soul output is deterministic from snapshots/events for tests.
- Same state does not repeatedly emit messages during cooldown.
- Critical -> recovery transition is covered by tests.
- Soul can be disabled.
- Reduce Motion is respected.

## G. Privacy/security
- No telemetry endpoint exists in MVP.
- No API key input UI exists.
- No Full Disk Access/root request exists solely for MVP features.
- Logs redact credentials and do not dump environment wholesale.

## H. Performance
- No monitor uses a busy loop.
- Monitor tasks stop/cancel correctly when app lifecycle requires.
- A profiling pass is completed before release; regressions are documented if the target idle CPU/memory cannot be met.
