# Product Scope — MacSoul v0.1

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
- Coarse region/ASN/ISP enrichment when privacy/reliability allows
- Shell/system proxy state
- VPN/tunnel hints
- Lightweight GitHub/OpenAI/Anthropic connectivity status

### 4. AI Coding
Only:
- Codex: 5h used %, reset; 1-week used %, reset
- Claude Code: 5h used %, reset; 1-week used %, reset

No token dashboard, costs, session analytics, model routing, or agent history.

### 5. Dev Environment
- Active Java/Node/Python/Go versions and executable paths
- Listening ports + owning process/PID
- Minimal process actions with confirmation

### 6. Cleaner Lite
- On-demand scan only
- Maven/Gradle/npm/pnpm/Playwright/Docker/Xcode categories where safely measurable
- Size, location, risk, explanation
- Prefer scan/explain over destructive automation in v0.1

## Explicitly deferred
- AgentScope / session replay
- project-to-process graph
- full Docker manager
- long-term timeline/daily report
- PRD/architecture tools
- cloud sync/accounts
- Windows/Linux
- rich notch animations
