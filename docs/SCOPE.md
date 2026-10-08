# Product Scope — MacSoul v0.1

## Published v0.1.0 scope

See [RELEASE](RELEASE.md) for public downloads and accepted boundaries. The original seven-day plan is closed within Owner-approved scope; historical increment verifying remains in the unchanged ledger. UI displays remaining quota, while canonical usedPercent / valid consumed 0% and >=95% alert logic retain their meanings. Only verified applicable/reported Live windows appear, with Week-only never inventing 5h. Codex exact versions: 0.160.0 / 0.160.1 / 0.162.0-alpha.2; unknown fail closed. Claude has no verified live source and stays unavailable. Broad Soul metaphors below are design vocabulary; current CPU/native-pressure transitions are documented in [SOUL-ENGINE](SOUL-ENGINE.md).

## One-line product
**MacSoul is a living developer control center for macOS: professional telemetry underneath, restrained personality on top.**

## Core modules
### 1. Soul
- CPU = Brain
- Memory = Stomach
- Disk = Home
- Battery = Energy
- Network = Connection to the world
- Ports = Doors
- AI quota = AI partner energy

Soul only reacts to meaningful state transitions and recovery; it never replaces the underlying metric.

### 2. System
- Aggregate CPU
- Memory + memory pressure
- Disk capacity
- Battery state
- Top developer-related processes

### 3. Network
- Public IPv4/IPv6 when available
- Region/ASN/ISP enrichment is a candidate, not implemented enrichment; Region is NOT_COLLECTED in v0.1.0
- Shell/system proxy state
- VPN/tunnel hints
- Lightweight GitHub/OpenAI/Anthropic connectivity status

### 4. AI Coding
Only Codex and Claude Code quota windows, up to 5h and 1-week per provider. Display the windows actually applicable and reported for the current account, with remaining % and available reset; canonical storage retains usedPercent. A Week-only account has no invented 5h bar. Do not infer window presence from Pro / Plus names.

Valid 0%, explicitly not applicable, unreported, request failed and stale are distinct states. Missing data is not evidence of unlimited quota; reset expiry does not clear the last used value.

No token dashboard, costs, session analytics, model routing, or agent history.

### 5. Dev Environment
- Active Java/Node/Python/Go versions and executable paths
- Listening ports + owning process/PID
- Copy port/PID/stop command; current App never executes termination. Any future execution needs separate design/authorization.

### 6. Cleaner Lite
- On-demand scan only
- Current catalog: Xcode DerivedData, Gradle caches, Maven repository/failed-download markers, npm _cacache, Homebrew downloads and local Docker logical storage. pnpm/Playwright are candidates, not current categories.
- Size, location, risk, explanation
- Owner-approved v0.1.0 boundary (2026-10-03): Discovery + read-only Scan + Explain + Content Preview. No cleanup, deletion selection or Trash actions. Existing cache locators remain groundwork; Maven/Gradle Build Tool analysis is deferred.
- v0.2.0 roadmap: separately design Cleaner cleanup (selection, Trash, confirmation, recoverability, policy/dry run), Maven/Gradle Build Tools and Docker cleanup/storage extensions. These are plans, not current implementation or acceptance.
- This roadmap clarification does not change original task IDs, baseline points, dependencies or historical acceptance. D5-01/02 were accepted with scoped Owner UI/real read-only scan evidence; original criteria and history remain intact.
- Scanned storage size is not guaranteed safe/reclaimable; do not label all downloaded artifacts safe.
- The approved seven-day scope is closed; future priorities require a new Owner-authorized work unit. Do not silently drop original requirements.

## Explicitly deferred
- AgentScope / session replay
- project-to-process graph
- full Docker manager
- long-term timeline/daily report
- PRD/architecture tools
- cloud sync/accounts
- Windows/Linux
- Notch implementation during bootstrap or after Day 5 freeze

## License decision

MacSoul original code that the project has the right to license is released under the MIT License, with `Copyright (c) 2026 liu-657667` in the root `LICENSE`. Third-party code, dependencies, and assets retain their original licenses and required notices; the MacSoul license does not relicense them. Historical inputs and concept assets under `reference/` are not automatically covered by the root license.
