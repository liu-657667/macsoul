# MacSoul PRD

## 1. Product definition
**MacSoul** is a native macOS developer control center.

Slogan: **Your Mac knows what you're building.**

It combines five concerns that developers repeatedly check in separate tools:
- **System** — CPU, memory pressure, disk, battery, developer processes.
- **Network** — public IP, proxy/VPN hints, DNS/basic connectivity.
- **Dev Environment** — active runtimes and listening ports.
- **AI Coding** — Codex and Claude Code quota only (5h + 1 week).
- **Soul** — a deterministic personality layer that turns meaningful state transitions into restrained, humorous reactions.

Cleaner and historical timeline are later releases, not MVP blockers.

## 2. Problem
Activity Monitor knows that `java` or `node` consumes resources, but not why a developer cares. Developers want quick answers such as:
- What is making my Mac slow?
- Which developer process is consuming memory?
- Who owns port 8080?
- Which Java/Node/Python/Go is active?
- Did my proxy actually take effect? What is my public IP?
- Can I reach GitHub/OpenAI/Anthropic?
- How much of my Codex/Claude Code 5h and weekly quota is used?

MacSoul puts those answers behind one menu-bar interaction.

## 3. Product principles
### Local first
Core telemetry remains on device. No account or cloud backend for MVP.

### Useful before playful
Every Soul reaction must map to real state and preferably link to a diagnostic view.

### Explain, do not guess
Unknown values display as unavailable. The app never fabricates quota, IP metadata, process ownership, or health conclusions.

### Developer-centric
Prefer `Port 8080 → java → PID 1234` over generic process tables. Future versions may add project mapping, but MVP must not pretend to know project identity when it does not.

### Quiet by default
The app must not become another source of interruptions. Most Soul messages stay inside the app/menu popover.

## 4. Target user
A macOS developer who uses several of: Terminal, IntelliJ/VS Code/Cursor, Docker, Java, Node.js, Python, Go, Codex, Claude Code, VPN/proxy tools.

## 5. MVP pages
- Overview
- System
- Network
- AI Coding
- Dev
- Settings

`Cleaner` may appear as "Coming later" only if it is visually useful; otherwise omit it until v0.2.

## 6. Overview
Overview is glanceable, not exhaustive.

It contains:
1. Soul face/state + one message.
2. System metrics: CPU, memory, disk, battery.
3. AI quota summary: Codex and Claude, 5h + week.
4. Network summary: public IP + proxy state.
5. Dev summary: Java/Node/Python/Go active versions + listening-port count.

Target: the user understands overall machine state in <5 seconds.

## 7. System requirements
### CPU
- Current total utilization.
- Top CPU consumers.
- Do not trigger Soul on short spikes; use sustained thresholds.

### Memory
- Prefer macOS memory pressure as primary health signal.
- Show used/total and swap as supporting metrics.
- Top memory consumers.

### Disk
- Total/used/free for system volume.
- v0.2 adds developer storage attribution and cleanup.

### Battery
- Charge percentage and charging state.
- Battery-health details are optional if available through stable APIs.

### Developer processes
Identify common developer-oriented processes where possible, e.g. Java, Node, Python, Go, Docker, database daemons, Vite/Next, Codex, Claude. Do not hide other heavy processes if they dominate CPU/memory.

## 8. Network requirements
### Public identity
Show public IPv4. IPv6 is optional for initial MVP but architecture must allow it.

Optional metadata when a provider supports it:
- country/region
- ASN
- ISP/network owner

All metadata must show its provider/source and fail gracefully.

### Proxy
Detect standard shell proxy variables and macOS system proxy configuration where practical. Distinguish environment-variable proxy from system proxy; do not collapse them into a false single truth.

### VPN/TUN
Best-effort signal only. Surface detected tunnel interfaces without claiming a vendor/provider unless reliable.

### Connectivity
Provide lightweight latency/reachability for GitHub, OpenAI, Anthropic, and one neutral control endpoint. A timeout means "probe failed", not "service is down".

## 9. Dev Environment requirements
### Runtimes
MVP supports:
- Java
- Node.js
- Python
- Go

For each, show active version and executable path when available. Detect common version managers as metadata, not as a full manager UI.

### Ports
Show listening TCP ports with owning PID/process when permissions allow.
Actions:
- Copy port
- Copy PID
- Ask before SIGTERM
- Separate explicit action for SIGKILL

## 10. AI Coding requirements
This module is intentionally small.

Providers in MVP:
- Codex
- Claude Code

User-facing quota windows for each provider:
- **5 hour usage + reset**
- **1 week usage + reset**

Also show:
- last updated
- data source
- unavailable/error state

Explicit non-goals:
- tokens
- cost
- model comparisons
- sessions
- Agent CPU/memory
- recommendations about which model to use
- burn-rate forecasting

## 11. Soul requirements
The Soul layer maps machine concepts to physical metaphors:
- CPU = brain
- memory = stomach
- disk = home/storage room
- battery = energy
- network = connection to the world
- ports = doors
- Docker = warehouse/basement (later richer support)
- AI quota = AI partner energy

Soul is a state machine with cooldown and recovery behavior. It must not speak on every sample.

Examples:
- sustained CPU critical → "我的脑子要爆炸了。"
- critical memory pressure → "我的胃快撑爆了。"
- disk nearly full → "家里已经快没地方下脚了。"
- battery critical → "我真的需要充电了。"
- network lost → "我看不到外面的世界了。"
- network restored → "回来了。"
- Claude 5h >95% → "Claude 快不行了。"

Localization should make messages data-driven; do not hard-code UI layout around Chinese strings.

## 12. Notifications
Most Soul messages remain in-app.

Default native notifications may be enabled for severe states only:
- battery <5%
- disk >95%
- critical memory pressure
- AI 5h/week >95% when quota data is available

CPU high does not notify by default.

## 13. Privacy/security
MVP must not:
- collect API keys
- read browser cookies
- read SSH keys
- upload process/port/path data
- scan source files
- require root

History storage is local. Network-history retention should be opt-in.

## 14. Performance targets
Targets, not excuses for unsafe optimization:
- idle CPU ideally <2%
- memory ideally <150 MB
- no hot polling loops
- no unbounded event/history growth

## 15. v0.2+ roadmap
### v0.2 — Clean your Mac
Explainable developer cleanup: Maven/Gradle/npm/pnpm/Docker/Xcode/Playwright/Homebrew/AI-tool caches. Each item must include size, path, risk, and explanation.

### v0.3 — Remember your Mac
Timeline and daily summary of meaningful events, not raw metric spam.

### v0.4 — Understand your Mac
Optional project/process/port relationships. This must remain local and evidence-based.
