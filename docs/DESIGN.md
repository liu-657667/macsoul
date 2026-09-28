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
5. Public IP + proxy setting / tunnel hint (not proof of routing)
6. `Open MacSoul`, `Settings`, `Quit`

Quota labels explicitly say “已用 / Used”. Both windows appear for each provider on both surfaces.
Unavailable quota renders `—` / `Unavailable`, never `0%`; no forced zero at reset expiry.
All prototype surfaces carry a visible Mock label until real data is validated.

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
- Cleaner summary only after an explicit read-only scan; scanned bytes are not guaranteed reclaimable bytes

### C. Notch experience — 后续版本增强，不在本次 Phase A / 七天冻结后实现
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

## Phase A status
Phase A source now implements the shared Mock snapshot and four quota windows. Build/unit evidence and remaining manual UI acceptance are recorded in `reports/phase-a.md`; the dated `review/AUDIT.md` remains historical findings.

## Phase A presentation contract

The main Overview, AI Coding page, and Menu Bar use one `AppSnapshot`. Each provider has two independent optional windows. Percentages are 0–100 in the model and are displayed as **used** quota; a missing window displays `Unavailable` with no progress bar. Reset is a timestamp, and expiry marks the old sample stale without zeroing its usage. Every provider displays mode, freshness, source, and sample time. All system/network/dev values in Phase A are clearly marked Mock or unavailable; memory used is not a health classification, so pressure is displayed separately. Cleaner shows only “scan not run” until a read-only scan exists.
