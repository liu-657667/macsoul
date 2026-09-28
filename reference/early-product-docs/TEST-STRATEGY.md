# Test Strategy

## Unit tests first for logic that agents can easily regress
1. Soul thresholds, hysteresis, cooldown, recovery.
2. Runtime command parsers.
3. Port/lsof parser if shell-backed.
4. Proxy parsing/normalization.
5. Codex rate-limit bucket selection.
6. Claude quota parser if/when a supported data source is adopted.
7. Formatter behavior for unavailable/stale values.

## Integration tests
Use dependency injection and fake providers. Avoid network/account dependencies in CI.

Suggested fake states:
- healthy all-data overview
- offline
- critical memory
- CPU spike vs sustained overload
- no battery
- no runtimes installed
- Codex installed/quota available
- Codex installed/only one quota window
- Claude installed/quota unavailable

## UI tests
Keep small:
- open menu popover
- open main window
- navigate feature sections
- unavailable states render without crash

## Manual release checklist
- launch-at-login behavior
- sleep/wake
- Wi-Fi switch/network change
- proxy toggle
- disconnected network
- long-running idle resource usage
- provider executable missing/updated
