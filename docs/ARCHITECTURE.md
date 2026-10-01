# MacSoul Architecture — v0.1

## Stack
- Swift + SwiftUI
- AppKit only for macOS-specific surfaces when SwiftUI is insufficient
- Apple frameworks/native APIs first
- UserDefaults/AppStorage for simple settings in v0.1
- Persistence only where required; do not introduce a database just to store current snapshots

## High-level architecture
```text
Native APIs / Provider Adapters
            ↓
       Sensor Hub
            ↓
   Immutable Snapshots
      ↙     ↓      ↘
   UI   SoulEngine  Alerts
```

**One sensor source per metric.** Views, menu bar, notch, and Soul all consume shared snapshots.

## Sampling tiers
### FAST
- CPU: background 3–5s; visible System page ~1s
- memory numeric summary: background 3–5s; visible ~1–2s
- process summary: background 10–15s; visible ~3s

### EVENT
- memory pressure changes
- battery/power changes when available
- network path changes
- Codex rate-limit updates when supported
- Claude local bridge updates when supported

### SLOW
- disk free: ~60s background
- public IP: ~5m + network-path change
- connectivity: ~60s, user-disableable
- ports: 30–60s background; 5–10s on Dev page
- runtimes: app start + manual refresh / ~5m cache

### ON DEMAND
- Cleaner recursive size scans
- Docker storage scan
- expensive diagnostics

## Adaptive sampling
When the main window is closed, reduce polling. When the relevant page is visible, temporarily increase freshness. A UI appearance change must update sampling policy rather than spawn a second monitor.

### Current System and Dev implementation
- One `SensorHub` publishes CPU, memory, Disk, battery and developer-process readings into the shared `AppSnapshot`; Overview, System and Menu Bar only read that snapshot.
- CPU and memory sample about every 1 second while System is visible and about every 5 seconds otherwise. Disk reads the root volume on Live entry and about every 60 seconds thereafter. Developer processes are sampled about every 3 seconds on System and 15 seconds in the background; their first CPU delta is unknown.
- Battery uses IOKit Power Sources for an initial read and power-source change notifications. If notification registration fails, it falls back to a 60-second refresh. An absent internal battery and an API failure have separate states.
- Disk reports root-volume `total − available` bytes and derives used percent from raw bytes; displayed capacities use GiB. APFS purgeable/shared-container behavior may differ from Storage Settings.
- A process CPU percentage is the difference in cumulative user + system CPU nanoseconds divided by elapsed wall-clock nanoseconds, multiplied by 100. One busy logical CPU is 100%; a multithreaded process can exceed 100%.
- These additional metrics do not drive Soul. AI quota still uses Mock data in Live mode; Network has its own shared monitor as described below.
- One `DevMonitor` publishes runtime contexts and current-user-visible TCP listening sockets into the same `AppSnapshot` consumed by Overview and Dev. Runtime commands are cached for 5 minutes by monotonic uptime. Port sampling is about 10 seconds while Dev is visible and about 60 seconds otherwise. A manual Dev refresh bypasses the runtime cache without restarting `SensorHub`.
- Port collection retains all visible TCP socket records, including distinct IPv4/IPv6 binds. Presentation groups PID + process + port into logical listeners and applies the shared `DeveloperProcessClassifier` only to the default Dev and Overview lists; the Dev disclosure reads the same snapshot to show all listeners. A listening port is not labeled as a conflict.
- Finder/GUI PATH, version manager default, and IDE project SDK are different contexts. Only detected executable paths are reported; an unresolved version-manager alias is not treated as an installed or active runtime.

### Current Network implementation
- One `NetworkMonitor` publishes a structured `NetworkSnapshot` into `AppSnapshot`; Overview, Network and Menu Bar read it. It never feeds Soul. Views do not initiate provider work.
- One effective `NWPathMonitor` uses a utility queue and reports status, used interface types, expensive/constrained and IP-family support. Preview/sleep cancels it; wake builds a new monitor and baseline. Generation checks reject earlier callbacks; cancelled HTTP work is awaited before a new batch starts.
- Public IPv4/IPv6 use isolated ipify endpoints via ephemeral URLSession, with 4s request / 5s resource limits, no cookies/credential store/cache and no redirects. GET bodies are streamed into a maximum 1024-byte buffer and validated per family. Family failures are independent; previous success is retained only with explicit stale/error presentation. Region is not collected.
- A deadline-based cancellable scheduler uses 300s Public IP TTL, 0.75s path-change debounce and 4s manual-refresh cooldown. Path changes invalidate older conclusions, merge triggers and reset probe backoff. Refresh does not restart NWPathMonitor, System or Dev.
- Local proxy/tunnel facts refresh initially, on path change/manual refresh and at 60s. Only scheme/host/port survive proxy parsing; userinfo, URL path/query and raw environment values never enter the snapshot. Uppercase proxy keys take precedence, with mismatch keys reported. Bypass lists are counted and compared by a canonical digest, without displaying their contents. CFNetwork system proxy and App environment contexts remain distinct. `getifaddrs` supplies only up tunnel-like interface names, without VPN routing claims.
- GitHub/OpenAI/Anthropic HEAD probes test unauthenticated HTTP/TLS response reachability, including 401/403/405; they do not test accounts or full service health. Success cadence is 60s; failures use 60/120/300/600/900s capped backoff. Disabling cancels pending probes and replaces old green results with Disabled. Enabling or meaningful path change schedules fresh work. Public IP queries remain separate from the probe toggle and are disclosed in Settings.
- External work starts only in explicitly selected Live mode. Preview restores the established fixtures. AI stays Mock and Cleaner remains Not Run. Native path status and HTTP outcomes must be accepted separately; path satisfied does not imply internet/service success.

## Modules
```text
MacSoul/
├── App/
├── Core/
│   ├── Models/
│   ├── Scheduling/
│   ├── Logging/
│   └── Errors/
├── Features/
│   ├── Overview/
│   ├── System/
│   ├── Network/
│   ├── AIQuota/
│   ├── Dev/
│   ├── Cleaner/
│   └── Settings/
├── Services/
│   ├── SensorHub/
│   ├── SystemMonitoring/
│   ├── NetworkMonitoring/
│   ├── RuntimeDetection/
│   ├── PortDetection/
│   ├── AIQuota/
│   ├── Cleaner/
│   └── Soul/
└── Providers/
    ├── Native/
    ├── Shell/
    ├── Network/
    ├── Codex/
    └── Claude/
```

## Native-first rules
- CPU/VM: Mach/host stats where practical.
- Memory health: memory pressure event + snapshot, not naive percent alone.
- Disk: FileManager/volume resource values.
- Network path: Network framework.
- Battery: stable IOKit/power APIs only.
- Processes: native/libproc preferred; shell fallback isolated and low-frequency.

## ShellRunner contract
Allowed for low-frequency developer tooling only.
- explicit executable + argument array
- async off main thread
- timeout + cancellation
- bounded stdout/stderr
- cache results
- never concatenate user-controlled shell strings
- `/usr/sbin/lsof -n -P -iTCP -sTCP:LISTEN -Fpcn` is parsed as fields. A quiet exit 1 means no visible matches; malformed output and command failure remain distinct. Sockets are deduplicated by PID, port and bind address.

## Snapshot types
### SystemSnapshot
sampledAt, cpuUsedPercent, memoryUsedBytes, memoryTotalBytes, memoryPressure, swapUsedBytes, diskTotalBytes, diskFreeBytes, batteryPercent?, charging?, topProcesses

### NetworkSnapshot
sampledAt, publicIPv4?, publicIPv6?, region?, asn?, isp?, environmentProxy, systemProxy, tunnelHints, connectivity, source metadata

### DevSnapshot
sampledAt, runtimes, listeningPorts

### AIQuotaSnapshot
provider, fiveHour: QuotaWindowState, weekly: QuotaWindowState, source, status, sampledAt

Each window distinguishes available (including 0%), not applicable, unreported, request failed and Provider unavailable. Presentation derives freshness per available window; all surfaces use one snapshot and shared display rules. See `AI-QUOTA.md`.

## Concurrency
Prefer structured concurrency/actors for shared mutable state. UI updates on MainActor. Providers must not block the main thread.
