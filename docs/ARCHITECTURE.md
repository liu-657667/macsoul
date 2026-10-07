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
- These additional metrics do not drive Soul. AI quota follows its separate capability boundary below; Network has its own shared monitor.
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
- External work starts only in explicitly selected Live mode. Preview restores the established fixtures. AI follows the separate quota-provider availability boundary described below. Live Cleaner starts Not Run and only scans after an explicit user action. Native path status and HTTP outcomes must be accepted separately; path satisfied does not imply internet/service success.

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

### Cleaner Lite — owner-approved read-only round

- Cleaner is executed before AI quota by explicit owner-approved order adjustment; original task IDs, days, points and dependency history remain intact. Only D5-01/02 are in scope.
- `CleanerSession`, owned once by AppStore, starts one `CleanerScanner` actor session from a user Scan action. Opening Cleaner/Overview, selecting Live or waking never starts a scan. No scanner timer; categories are scanned sequentially and only counters are retained.
- A structured `CleanerSnapshot` feeds Cleaner and Overview. Developer Preview retains the existing Mock fixture boundary; Live starts at Not Run with no Mock sizes. Page navigation does not cancel an explicit scan; Preview, sleep and app termination cancel. Session generations reject old Preview-cycle results, and a new scan is blocked until the old task ends.
- The fixed catalog contains Xcode DerivedData, Gradle caches, Maven local repository and its failed-download markers, npm `_cacache` only, and Homebrew download cache. It never treats installed runtime versions, projects or Docker disks as caches. There is no arbitrary-path input/API in normal business use.
- Foundation DirectoryEnumerator streams the traversal off MainActor. Root/ancestor symlinks are rejected, internal symlinks skipped, lexical and resolved containment checked. Descendant errors preserve a Partial estimate; missing/inaccessible/cancelled remain distinct from zero. Cancellation is checked on every iteration; Task yields at 64-entry intervals and counter updates are throttled to 200ms.
- Regular files prefer totalFileAllocatedSize, then fileAllocatedSize, then nonnegative fileSize fallback. Directory metadata is not added. GiB uses 2^30 bytes. No inode deduplication or APFS clone/shared-block accounting; this is estimated disk usage, not reclaimable bytes. Files changing concurrently can make it a partial/current estimate rather than an atomic filesystem snapshot.
- Risk is descriptor-defined usual recovery cost, never inferred from size. Maven/Gradle are Caution. Only Reveal in Finder and Copy path are offered, alongside Scan/Rescan/Cancel. No deletion, cleanup command, shell interpreter, Cleaner network provider or Menu Bar Cleaner details. Bounded tool queries added in the refinement below do not run cleanup commands.

- `MavenRepositoryLocator` performs bounded local discovery only when Scan is requested: user settings → known Maven installation global settings → default candidate. No Maven invocation, shell initialization, recursive discovery or network. Only top-level `localRepository` is retained by XMLParser; settings reads are capped at 64 KiB, external entities/DTDs rejected, `${user.home}` is supported and unknown properties remain Unresolved. Explicit JVM/project repository overrides are NOT_DISCOVERED.
- Maven repository and `.lastUpdated` descriptors share the same discovered location. A generic matchingFiles target filters names during metadata traversal, never reads marker contents. Marker bytes are already in repository usage and do not contribute to the summary again. Small marker sizes use bytes/KiB/MiB; primary estimates use GiB. The marker descriptor requires a second sequential streaming pass, never concurrent traversal or a stored file list.

### Cleaner locator / Docker refinement (2026-10-03)

- Catalog paths are documented fallback candidates. Production Scanner first awaits `CleanerLocator`, which emits `ResolvedCleanerTarget` URL/source/state; only resolved targets enter the existing metadata walker. All cards distinguish detected configuration from labelled defaults. Xcode custom preferences are NOT_DISCOVERED rather than guessed.
- Gradle uses App `GRADLE_USER_HOME` then a labelled default and always selects its caches child. npm uses cache environment, otherwise direct bounded `npm config get cache`, otherwise a labelled default; only `_cacache` is traversed. Homebrew uses bounded direct `brew --cache` or a labelled default. Known tool lookup reuses Dev ExecutableResolver with PATH and two fixed bin prefixes; no HOME search. Maven retains bounded XML discovery and one shared root for parent/markers. Unresolved/failed explicit queries are not disguised as configured defaults.
- Direct queries use the existing ShellRunner with short timeouts/output caps; no shell initialization or mutation commands. Discovery reporting may use a separate observer, but the App runs discovery inside the single explicit Scan task, not on launch/page appearance.
- `DockerCleanerAdapter` is an independent logical category in the same CleanerSnapshot/session. It uses direct context show/inspect and `system df --format {{json .}}` only after Scan. Only a parsed Unix endpoint counts as local; TCP/SSH (including loopback) are conservatively remote and storage is not queried or added. Unknown context/CLI/daemon/response states are not zero bytes. Context/host precedence respects Docker's environment semantics.
- Docker's four aggregate logical categories contribute once, without scanning Docker.raw/qcow2 or VM directories. Reported decimal SI sizes are parsed into bytes, then displayed with explicit binary units; these rounded Docker logical estimates are not physical filesystem allocation or safe deletion guarantees. Reclaimable is labelled as Docker-reported, never a cleanup action. Combined summary labels mixed file-allocation/local-Docker semantics; remote totals and marker children do not double count.


### Cleaner content preview — owner-approved v0.1.0 boundary (2026-10-03)

- Summary retains aggregate counters. Only an explicit View contents action opens an AppStore-owned CleanerPreviewSession; it never saves a whole tree. The Preview scanner lists direct children (up to 2,000, with an explicit incomplete/ranking notice), then sequentially estimates directory children using the existing read-only aggregate scanner without locator/Docker calls. File sizes retain the existing allocated/logical fallback semantics; directory metadata is not added.
- A preview item has stable root-relative ID, name/path/URL, kind, optional estimated allocated bytes/count and state. Size-descending/name sorting is presentation only. Links are visible but never counted or entered; errors/unknown sizes are not zero. Maven marker preview estimates only matching files, explicitly separate from repository total.
- A resolved category establishes the boundary. Direct-child membership, lexical/resolved containment and ancestor/root links are checked. Navigation accepts only current snapshot directory items and known breadcrumbs; there is no path input or HOME browser. Files changing during traversal can still affect estimates; this is not an atomic filesystem snapshot.
- One shared preview session serializes cancelled loads before category/drill-down/back replacements. Summary and Preview recursive scans are mutually exclusive at AppStore; closing the detail/section, selecting Developer Preview, sleep or App termination cancels Preview. No automatic wake/page-appearance scan. Progress updates are throttled to 200ms; listings and terminal states are published immediately.
- Docker detail displays the existing four logical rows and reported reclaimable estimate from the shared snapshot only. It never launches a second CLI query, enumerates images/containers or visits VM files. Category primary action is View contents; Finder and Copy path remain auxiliary actions. No cleanup selection or mutation controls.
- v0.2.0 cleanup / Maven-Gradle Build Tools / Docker extensions are roadmap only; the original task ledger/history is retained. UI/real scan and formal Performance acceptance remain separate from unit/build evidence.


### AI quota — first-phase capability boundary (2026-10-04)

- One AppStore-owned AIQuotaMonitor owns one CodexQuotaProvider and one ClaudeQuotaProvider. The existing QuotaItem/QuotaWindowState contract is retained. Details track connection/capability independently of numeric windows. AppSnapshot quotas feed Overview, AI Coding and Menu Bar; no view calls a provider.
- Production Codex startup requires an explicit constructor authorization gate, currently closed. Native stdio transport uses a literal executable/arguments, a temporary working directory, bounded 64-KiB JSON lines/32 queued messages and detached pipe draining. Its outbound allowlist permits initialize, initialized and account/rateLimits/read only. Diagnostics and unrelated notifications are discarded. No prompt/thread/login/account mutation API is exposed.
- After authorization, the candidate connection performs one handshake/read and consumes updates, with 10s handshake/read timeout and 1/2/5/10/30/60s capped retry. Stop cancels watchdog/backoff, tears down/reaps the owned child and awaits the preceding generation before starting again. Generation checks reject old publication. Sleep, Preview and normal App termination stop quota providers; the termination delegate waits for quota child teardown. No periodic quota refresh is enabled.
- Claude version discovery reuses ExecutableResolver/ShellRunner. No detected executable or verified installed bridge means honest unavailable, without inferring subscription/auth from installation. A pure sanitized-field parser is tested; bridge installation and real quota observation are not performed.
- QuotaAlertEngine consumes only fresh Live numeric windows with real reset identity. Its reset-scoped dedupe history survives provider lifecycle changes. Events/Soul copy are exposed in memory; no system notification permissions or system Soul state-machine redesign.
- Installed Codex protocol support and actual quota UI behavior are still pending owner authorization/acceptance. Performance is NOT_RUN. These implementation boundaries do not replace earlier human acceptance evidence.

### AI quota — verified Codex integration (2026-10-04)

The later Owner-approved capability result supersedes the historical first-phase closed gate. MacSoulApp injects the native provider for the verified bundled CLI 0.160.0; default/injected AppStores and the XCTest host remain fail-closed. Live activation owns one child, one serialized initial/240s verification read path and a bounded event stream. Read IDs and connection/generation checks reject stale replies. Automatic disconnect retains numeric values/time; explicit stop/sleep/Preview clears baseline. No profile read, credential-store read, inference or auth mutation is exposed. Typed bucket plan semantics can establish missing 5h non-applicability under current verified Pro policy; unknown and future semantics stay unreported. Actual reported windows always win. See AI-QUOTA.md for the contract and report for evidence; real MacSoul AI UI / cross-client propagation / alerts and formal Performance remain NOT_RUN.

### Day 6 review boundary (2026-10-07, pending Owner review)

Historical capability checkpoints above are retained. Current accepted integration supports exactly Codex CLI 0.160.0 and 0.160.1, event updates plus serialized 240s verification reads; unknown versions fail closed. Quota canonical `usedPercent` remains unchanged, while visible bars, numeric text and accessible values express **remaining**. Natural memory-pressure warning was observed; critical was not. System/Dev/Network/Cleaner/AI Day 2–5 reports describe the accepted baseline.

Day 6 adds a native Settings scene (system Cmd+,) and an injected `LoginItemManaging` adapter for `SMAppService.mainApp`. Reading/refreshing status never registers/unregisters; only an explicit switch action mutates system state. The native system status is authoritative, approval/unavailable/error remain explicit. No LoginAgent, helper daemon, persistent bool or actual automated owner registration.

Pipe teardown uses a shared cancellation pipe to wake native blocking `poll` readers without a periodic polling timer. Bounded chunks and existing output limits remain; cancellation/close no longer require EOF from descendant-inherited pipe writers. Only the directly launched owned process is eligible for termination; no descendant/user-PID kill is introduced. Prior generation teardown still precedes new source startup. Native table selection/accessibility labels change presentation, not provider snapshots/cadence.

### Day 6 Owner closeout (2026-10-07)

The earlier review checkpoint above is retained. Owner accepted the unchanged Day6 implementation and scoped VoiceOver/keyboard/Reduce Motion checks. Native Login Item implementation/status honesty accepted; real register/unregister remains NOT_RUN, explicitly deferred to Day7 installed/signed build. The existing30-minute CPU result is PASS and RSS remains REVIEW ACCEPTED. No architecture/product behavior changed during closeout; Day7 has not started. See the Day6 report Final Owner Acceptance.
