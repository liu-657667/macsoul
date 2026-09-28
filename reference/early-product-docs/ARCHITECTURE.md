# MacSoul Architecture

## 1. Technical direction
- Swift + SwiftUI for UI and app lifecycle.
- AppKit only for capabilities SwiftUI does not cleanly expose (menu-bar/window integration if needed).
- Prefer Apple frameworks and native APIs.
- Persistence can start lightweight; use SQLite only when history is introduced. MVP settings can use AppStorage/UserDefaults where appropriate.
- Minimum deployment target: choose the lowest modern macOS version that supports the selected APIs without compatibility contortions; record the final choice in the Xcode project and README. Do not silently raise it later.

## 2. Dependency rule
UI depends on feature view models/protocols, never directly on shell/network implementations.

```text
Views
  ↓
ViewModels / Feature Models
  ↓
Domain Services
  ↓
Provider Protocols
  ↓
Native Providers | Shell Fallbacks | Network Providers
```

## 3. Suggested source layout
```text
MacSoul/
├── App/
│   ├── MacSoulApp.swift
│   ├── AppState.swift
│   └── MenuBar/
├── Core/
│   ├── Models/
│   ├── Errors/
│   ├── Utilities/
│   └── Scheduling/
├── Features/
│   ├── Overview/
│   ├── System/
│   ├── Network/
│   ├── AIQuota/
│   ├── Dev/
│   └── Settings/
├── Services/
│   ├── SystemMonitoring/
│   ├── ProcessMonitoring/
│   ├── NetworkMonitoring/
│   ├── RuntimeDetection/
│   ├── PortDetection/
│   ├── AIQuota/
│   └── Soul/
├── Providers/
│   ├── Native/
│   ├── Shell/
│   ├── Network/
│   ├── Codex/
│   └── Claude/
└── Resources/
    └── Localizable.xcstrings
```

## 4. Snapshot models
Use immutable snapshots between monitoring services and UI where possible.

### SystemSnapshot
Suggested fields:
- sampledAt
- cpuUsedPercent
- memoryUsedBytes
- memoryTotalBytes
- memoryPressure enum: normal/warn/critical/unknown
- swapUsedBytes
- diskTotalBytes
- diskFreeBytes
- batteryPercent optional
- isCharging optional
- topProcesses

### NetworkSnapshot
- sampledAt
- publicIPv4 optional
- publicIPv6 optional
- country/region/asn/isp optional
- shellProxy configuration
- systemProxy configuration
- tunnelInterfaces
- connectivity results
- source metadata

### DevSnapshot
- sampledAt
- runtimes [RuntimeSnapshot]
- listeningPorts [ListeningPort]

### AIQuotaSnapshot
- provider enum
- fiveHour: QuotaWindow?
- weekly: QuotaWindow?
- source
- sampledAt
- status: available/unavailable/error

### QuotaWindow
- usedPercent
- duration
- resetsAt

## 5. Monitor scheduling
Suggested defaults:
- CPU/memory: 2s
- process summary: 3–5s
- disk: 30s
- battery: 30s
- listening ports: 10s
- runtime versions: 5m or manual refresh
- AI quota: 60s while app active; back off when idle/background
- public IP: 5m and on network-path change
- connectivity: 60s, opt-out in Settings

Centralize scheduling so feature services do not create unmanaged timers.

## 6. Native vs shell strategy
Prefer native APIs for frequently sampled metrics.

Acceptable shell fallbacks for low-frequency developer data include `java -version`, `node --version`, `python3 --version`, `go version`, `which`, and `lsof` if no practical native implementation is available for MVP.

Shell runner requirements:
- explicit executable + arguments, never untrusted concatenated shell strings
- timeout
- async execution off main thread
- bounded output
- caching
- cancellation
- structured result including exit code/stderr

## 7. System monitoring implementation notes
### CPU/memory
Prefer Mach/host statistics for aggregate CPU and VM data. Memory health should expose memory pressure, not only a naive used-percent calculation.

### Processes
Prefer native process APIs/libproc where feasible. It is acceptable to begin with a provider abstraction and a shell-backed implementation if this materially speeds the MVP, provided polling is not aggressive.

### Disk
Use FileManager/URL resource values for volume capacity.

### Battery
Use stable IOKit/power-source APIs only. If health/temperature data requires unstable/private APIs, omit it from MVP.

## 8. Network implementation notes
Use `NWPathMonitor` for network-path state changes, but do not treat it as public-IP truth.

Public-IP discovery must be behind `PublicIPProvider`. Provider failures must not break Network UI. ASN/geo metadata is optional enrichment and may be a separate provider due to privacy/reliability concerns.

Proxy inspection should distinguish:
- process environment variables
- macOS system proxy settings
- tunnel/VPN interface evidence

## 9. AI quota architecture
Define:
```text
protocol AIQuotaProvider {
    var provider: AIProvider { get }
    func availability() async -> ProviderAvailability
    func fetchQuota() async throws -> AIQuotaSnapshot
}
```

Codex and Claude implementations must be isolated. See `AI-QUOTA.md`.

## 10. Soul architecture
`SoulEngine` consumes normalized snapshots/events and emits a `SoulPresentation`:
- state
- severity
- messageKey
- optional action
- timestamp

The engine must not import UI frameworks.

## 11. Event model
MVP can keep only current state plus a small in-memory recent-event buffer. v0.2+ may persist meaningful events.

An event is a transition such as `memory.normal -> critical`, not every 2-second sample.

## 12. Error model
Provider errors should be scoped:
- permission denied
- command unavailable
- timeout
- parse failure
- network unavailable
- unsupported
- provider changed

UI renders feature-local unavailable/error states while the rest of the app remains functional.

## 13. Concurrency
Use structured Swift concurrency. Monitors should be actors or otherwise protect mutable shared state. Avoid orphaned Tasks and timers.

## 14. Testing boundaries
High-value tests:
- threshold/hysteresis/state transitions
- Soul cooldown and recovery
- command-output parsers using fixtures
- Codex/Claude quota response parsers using fixtures
- proxy parser
- runtime version parser
- port parser
- provider fallback/unavailable behavior

Do not require live network or installed Codex/Claude in unit tests.
