# UI Specification

## Visual character
Native macOS, quiet, dark-mode friendly, developer-oriented, slightly playful. Avoid cyberpunk HUDs, enterprise KPI dashboards, giant gradients, and pet-game aesthetics.

The Soul character is a minimal custom vector/shape, not an emoji dependency.

## 1. Menu bar popover
Primary quick-check surface.

Order:
1. Soul state + one short message
2. CPU + memory
3. Codex: `5h xx% · Week xx%`
4. Claude: `5h xx% · Week xx%`
5. Public IP + proxy indicator
6. Buttons: Open MacSoul / Settings / Quit

If quota is unavailable, show `—`, not `0%`.

## 2. Overview
Use compact cards/sections; no scrolling wall of metrics.

### Soul header
- Character/state icon
- Mood label
- One message
- Optional action button such as `View Memory`, `View Ports`, `Open Network`

### System strip
CPU / Memory / Disk / Battery. Clicking navigates to System.

### AI quota card
Two provider rows. Each row has two progress bars or compact gauges: 5h and Week, plus nearest reset text when available.

### Network card
Public IP, coarse metadata if available, proxy state, connectivity summary.

### Dev card
Java, Node, Python, Go active versions; listening-port count.

## 3. System page
Sections:
- CPU + top consumers
- Memory pressure + used/total/swap + top consumers
- Disk
- Battery
- Developer-heavy processes

Do not build full Activity Monitor parity.

## 4. Network page
Sections:
- Public identity
- Proxy/system proxy
- Tunnel/VPN hints
- Connectivity probes

Every remote datum shows last-updated/source affordance in details.

## 5. AI Coding page
Intentionally minimal.

For each provider:
```text
Codex
5 Hour    [========----] 62%   resets in 2h 18m
1 Week    [====--------] 31%   resets in 4d 6h
Updated 13:42 · Source: Codex app-server
```

Claude follows the same visual schema. Unsupported/missing windows render `Unavailable`.

No other charts in v0.1.

## 6. Dev page
### Runtime cards
For Java/Node/Python/Go:
- active version
- executable path
- manager hint when reliable
- mismatch warning when evidence exists

### Listening ports
Columns: Port, Process, PID, optional protocol/address.
Actions from a context menu or trailing button: Copy Port, Copy PID, Terminate…

## 7. Settings
- Launch at login
- Soul on/off
- Soul intensity: Quiet / Normal (no "chatty" in MVP)
- Native critical notifications on/off
- Connectivity probes on/off
- Store AI usage history (future-ready; may be disabled in MVP)
- Network history off by default
- Appearance system/light/dark

## Accessibility
- All status is conveyed by text/icon in addition to color.
- Respect Reduce Motion.
- Keyboard navigation for main controls.
- Soul text is not the only representation of critical state.
