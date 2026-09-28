# MacSoul Product & UI Design

## Design principle
The product must be useful first, memorable second. The personality should make telemetry understandable, not turn MacSoul into a pet game.

## Surface hierarchy
### A. Menu Bar — P0, every Mac
This is the universal always-available surface.
The supplied `MacSoulMenuTemplateDraft` is active in the Phase A Mock build for small-size review after the owner's 2026-09-28 approval to use the generated visual assets. Its asset name and Draft status remain until the native menu bar appearance is accepted.
The popover uses the opaque semantic window background so quota text stays legible over any desktop wallpaper in both system appearances.

Popover order:
1. Soul state + one line
2. CPU, memory used, disk and battery in a compact 2×2 grid; unavailable values remain explicit, with memory pressure shown separately
3. Codex: applicable 5h / Week windows and their state
4. Claude: applicable 5h / Week windows and their state
5. Public IP + proxy setting / tunnel hint (not proof of routing)
6. `Open MacSoul`, `Settings`, `Quit`

Quota labels explicitly say “已用 / Used”. Main Overview, AI Coding and Menu Bar use the same row component and state rules: two applicable windows produce two rows; an explicitly Week-only provider produces one Week row and a small “5h not applicable” note, with no 5h progress bar. An unreported window or failed request has a status row without progress, distinct from not applicable. A valid 0% renders `0% used` with a zero progress value. Stale values retain their last used % and are marked stale; reset expiry never forces zero.
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
Soul uses a restrained state glyph or approved artwork, not an emoji-dependent rendering.
- Calm: neutral/relaxed
- Busy: focused
- Stressed: strained
- Critical: overloaded
- Recovering: relief

Avoid excessive animation. Respect Reduce Motion.

The original minimal vector face remains the unavailable-state fallback. The supplied six-image ghost set is used in the Mock UI: `normal`, `busy`, CPU overload, memory pressure, low battery and resting. It is static raster artwork, with a fixed layout frame and adjacent state text. This visual set does not change Soul thresholds or imply live sampling. The owner confirmed the six states and Dock icon in the current appearance; dark appearance remains unverified.

## Example state-to-action interactions
- `我的脑子要爆炸了。` → opens CPU/top processes.
- `我的胃快撑爆了。` → opens memory pressure/top consumers.
- `8080 这扇门已经有人占了。` → opens Dev/Ports.
- `Claude 快不行了。` → opens AI Coding.
- `嗯？我们搬家了？` → opens Network.

## AI quota page
Intentionally boring and clear; rows below are examples, not four mandatory windows:

```text
Codex
5 Hour   [=======---] 72%    resets in 1h 42m
1 Week   [===-------] 31%    resets in 4d 9h

Claude Code
5 Hour   [========--] 84%    resets in 52m
1 Week   [=====-----] 47%    resets in 3d 6h
```

No extra charts in v0.1.

For a Week-only account, show its Week row and a “5h not applicable” note. If 5h is unreported rather than explicitly inapplicable, show “5h · Not reported” with no bar. Request failure has its own label. Data freshness and source remain visible. Quota reminders and Soul quota copy may use only fresh, applicable numeric windows.

## Empty/unavailable states
- Provider not installed: `Not detected`
- Installed but quota inaccessible: `Quota unavailable`
- Network offline: `Offline`
- Stale data: show last successful update time

## Visual direction
Native macOS, quiet, dense enough for developers, dark-mode strong, light-mode correct.
Avoid cyberpunk HUD, crypto dashboard aesthetics, huge gradients, and enterprise KPI styling.

## Phase A status
Phase A historically used a four-window Mock fixture. The owner revised the current requirement on 2026-09-28 to dynamic applicable windows; the old reports and dated `review/AUDIT.md` remain historical evidence.

## Phase A presentation contract

The main Overview, AI Coding page, and Menu Bar use one `AppSnapshot` and one quota row implementation. Each 5h/Week window is independently `available`, `notApplicable`, `unreported`, `requestFailed` or `providerUnavailable`; an available window may display as stale when its sample ages or reset time passes. Percentages are 0–100 and mean **used** quota. Only `notApplicable` suppresses the window row; other nonnumeric states never get a progress bar. Reset is a timestamp, and expiry marks the old sample stale without zeroing usage. Mode, source and sample time are visible. All system/network/dev values in Phase A are clearly marked Mock or unavailable; memory used is not a health classification, so pressure is displayed separately. Cleaner shows only “scan not run” until a read-only scan exists.
