# Product Decisions

These decisions are intentionally explicit so an agent does not expand scope while "helping".

## D1 — Native macOS
Use Swift/SwiftUI. Electron/Tauri/webview are out of scope for the initial product.

## D2 — Menu bar first
The primary interaction is a menu-bar popover plus an optional main window. The app should remain useful without leaving a dashboard open.

## D3 — Soul is not a chatbot
Soul uses local rules/templates in MVP. No chat input and no LLM calls are required.

## D4 — AI Coding means quota only
Codex and Claude Code show exactly 5-hour and 1-week quota windows when verifiably available. No token/cost/session dashboard.

## D5 — No fabricated provider data
When a stable/allowed source is unavailable, display `Unavailable`. Keep providers replaceable so integrations can evolve.

## D6 — Cleaner is post-MVP
Do not block v0.1 on disk-cache discovery or cleanup actions.

## D7 — No project inference in v0.1
Do not label a process as belonging to a project unless there is reliable evidence. Basic process/PID/port mapping is enough.

## D8 — Minimal permissions
Do not add Accessibility, Full Disk Access, or root requirements merely for convenience. If a future feature needs permission, document exactly why and degrade gracefully without it.

## D9 — No telemetry by default
No remote analytics in MVP. If crash reporting or opt-in metrics are proposed later, they require a separate decision.

## D10 — Internationalization-ready
The initial UI can ship with Chinese/English strings, but Soul copy and labels must live in localization resources rather than inside state logic.
