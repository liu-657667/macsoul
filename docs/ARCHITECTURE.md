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

## Snapshot types
### SystemSnapshot
sampledAt, cpuUsedPercent, memoryUsedBytes, memoryTotalBytes, memoryPressure, swapUsedBytes, diskTotalBytes, diskFreeBytes, batteryPercent?, charging?, topProcesses

### NetworkSnapshot
sampledAt, publicIPv4?, publicIPv6?, region?, asn?, isp?, environmentProxy, systemProxy, tunnelHints, connectivity, source metadata

### DevSnapshot
sampledAt, runtimes, listeningPorts

### AIQuotaSnapshot
provider, fiveHour?, weekly?, source, status, sampledAt

## Concurrency
Prefer structured concurrency/actors for shared mutable state. UI updates on MainActor. Providers must not block the main thread.
