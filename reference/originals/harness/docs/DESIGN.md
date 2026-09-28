# MacSoul Product & UI Design

## Design principle
The product must be useful first, memorable second. The personality should make telemetry understandable, not turn MacSoul into a pet game.

## Surface hierarchy
### A. Menu Bar — P0, every Mac
This is the universal always-available surface.

Popover order:
1. Soul state + one line
2. CPU + memory
3. Codex: `5h xx% · Week xx%`
4. Claude: `5h xx% · Week xx%`
5. Public IP + proxy/VPN indicator
6. `Open MacSoul`, `Settings`, `Quit`

Unavailable quota renders `—` / `Unavailable`, never `0%`.

### B. Main window — P0
Navigation:
- Overview
- System
- Network
- AI Coding
- Dev
- Cleaner
- Settings

Overview composition:
- Soul header
- System strip
- AI quota card
- Network card
- Dev card
- Cleaner summary only after scan

### C. Notch experience — P2 enhancement
For MacBook displays with a notch only.
- It is a secondary presentation of existing snapshots.
- No unique controls or data.
- Default collapsed: tiny Soul state / subtle status.
- On hover/click: compact CPU/RAM + Codex/Claude quota.
- Critical state may change the Soul expression once; no persistent flashing.
- If capability detection is unreliable or requires private APIs, do not ship it in v0.1.

## Soul visual style
Minimal vector face/state glyph, not emoji-dependent.
- Calm: neutral/relaxed
- Busy: focused
- Stressed: strained
- Critical: overloaded
- Recovering: relief

Avoid excessive animation. Respect Reduce Motion.

## Example state-to-action interactions
- `我的脑子要爆炸了。` → opens CPU/top processes.
- `我的胃快撑爆了。` → opens memory pressure/top consumers.
- `8080 这扇门已经有人占了。` → opens Dev/Ports.
- `Claude 快不行了。` → opens AI Coding.
- `嗯？我们搬家了？` → opens Network.

## AI quota page
Intentionally boring and clear:

```text
Codex
5 Hour   [=======---] 72%    resets in 1h 42m
1 Week   [===-------] 31%    resets in 4d 9h

Claude Code
5 Hour   [========--] 84%    resets in 52m
1 Week   [=====-----] 47%    resets in 3d 6h
```

No extra charts in v0.1.

## Empty/unavailable states
- Provider not installed: `Not detected`
- Installed but quota inaccessible: `Quota unavailable`
- Network offline: `Offline`
- Stale data: show last successful update time

## Visual direction
Native macOS, quiet, dense enough for developers, dark-mode strong, light-mode correct.
Avoid cyberpunk HUD, crypto dashboard aesthetics, huge gradients, and enterprise KPI styling.
