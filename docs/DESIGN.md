# MacSoul Product & UI Design

## Design principle
The product must be useful first, memorable second. The personality should make telemetry understandable, not turn MacSoul into a pet game.

## Surface hierarchy
### A. Menu Bar — P0, every Mac
This is the universal always-available surface.
The supplied `MacSoulMenuTemplateDraft` is active in the Phase A Mock build for small-size review after the owner's 2026-09-28 approval to use the generated visual assets. Its asset name and Draft status remain until the native menu bar appearance is accepted.
The popover uses an opaque semantic window background and semantic text colors so the desktop wallpaper does not show through body text in either system appearance.

Popover order:
1. Soul state + one line
2. CPU, memory used, disk and battery in a compact 2×2 grid; unavailable values remain explicit, with memory pressure shown separately
3. Codex: applicable 5h / Week windows and their state
4. Claude: applicable 5h / Week windows and their state
5. Public IP + proxy setting / tunnel hint (not proof of routing)
6. `Open MacSoul`, `Quit MacSoul`

Quota labels explicitly say “已用 / Used”. Main Overview, AI Coding and Menu Bar use the same row component and state rules: two applicable windows produce two rows; an explicitly Week-only provider produces one Week row in Overview and Menu Bar, with no 5h note or progress bar. AI Coding detail may explain the absent window. An unreported window or failed request has a status row without progress, distinct from not applicable. A valid 0% renders `0% used` with a zero progress value. Stale values retain their last used % and are marked stale; reset expiry never forces zero. Overview and Menu Bar use short reset hints for fresh values; source, exact sample time and full reset time are in AI Coding details.
All prototype surfaces carry a visible Mock label until real data is validated.

The Settings page groups current build capabilities, app-only appearance/language choices and developer preview scenarios at the top. Appearance offers Follow macOS, Light and Dark; language offers English and 简体中文. These choices affect MacSoul's main window and Menu Bar content without changing macOS settings or the shared snapshot. Native macOS menu chrome follows the system language.
Cleaner uses the Phosphor broom SVG as a monochrome template icon in the sidebar and Overview card. It does not imply deletion is enabled; Phase A Cleaner remains read-only/unrun. Its original license travels with the app bundle.

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

The original minimal vector face remains the unavailable-state fallback. The supplied six-image ghost set is used in the Mock UI: `normal`, `busy`, CPU overload, memory pressure, low battery and resting. It is static raster artwork, with a fixed layout frame and adjacent state text. This visual set does not change Soul thresholds or imply live sampling. The owner confirmed the normal state on both surfaces; the Dock icon and five other Soul states remain for current manual review.

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

For a Week-only account, show its Week row in Overview and Menu Bar; AI Coding detail may show a “5h not applicable” explanation. If 5h is unreported rather than explicitly inapplicable, show “5h · Not reported” with no bar. Request failure has its own label. Abnormal freshness stays visible in summaries; normal freshness and source are available in details. Quota reminders and Soul quota copy may use only fresh, applicable numeric windows.

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

The main Overview, AI Coding page, and Menu Bar use one `AppSnapshot` and one quota row implementation. Each 5h/Week window is independently `available`, `notApplicable`, `unreported`, `requestFailed` or `providerUnavailable`; an available window may display as stale when its sample ages or reset time passes. Percentages are 0–100 and mean **used** quota. Only `notApplicable` suppresses the summary window row; other nonnumeric states never get a progress bar. Reset is a timestamp, and expiry marks the old sample stale without zeroing usage. Mock mode remains visible in summaries; source and exact sample time are in AI Coding detail. All system/network/dev values in Phase A are clearly marked Mock or unavailable; memory used is not a health classification, so pressure is displayed separately. Cleaner shows only “scan not run” until a read-only scan exists.
