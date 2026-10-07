import Foundation
import Combine
import AppKit

protocol SnapshotProvider { func snapshot(now: Date) -> AppSnapshot }
struct MockProvider: SnapshotProvider {
    enum Fixture: String, CaseIterable, Identifiable {
        case healthy, busy, cpuCritical, cpuRecovery, memoryPressure, lowBattery, sleeping
        case quota95, codexWeeklyOnly, claudeWeeklyOnly, codexUnreported, claudeUnreported
        case zeroUsage, requestFailed, staleOffline, noBattery

        var id: String { rawValue }
        var label: String {
            switch self {
            case .healthy: "Normal"
            case .busy: "Busy"
            case .cpuCritical: "CPU overload"
            case .cpuRecovery: "CPU recovery"
            case .memoryPressure: "Memory pressure"
            case .lowBattery: "Low battery"
            case .sleeping: "Resting"
            case .quota95: "Quota 95%"
            case .codexWeeklyOnly: "Codex: Week only"
            case .claudeWeeklyOnly: "Claude: Week only"
            case .codexUnreported: "Codex: 5h not reported"
            case .claudeUnreported: "Claude: Week not reported"
            case .zeroUsage: "Valid 0% quota"
            case .requestFailed: "Quota request failed"
            case .staleOffline: "Stale / offline"
            case .noBattery: "No battery"
            }
        }
        var soulVisual: SoulVisual {
            switch self {
            case .busy: .busy
            case .cpuCritical: .overload
            case .memoryPressure: .bloated
            case .lowBattery: .lowBattery
            case .sleeping: .sleeping
            default: .normal
            }
        }
        var soulMood: String {
            switch self {
            case .busy: "Busy · Mock"
            case .cpuCritical: "Overload · Mock"
            case .memoryPressure: "Memory pressure · Mock"
            case .lowBattery: "Low battery · Mock"
            case .sleeping: "Resting · Mock"
            case .cpuRecovery: "Recovering · Mock"
            default: "Calm · Mock"
            }
        }
        var soulMessage: String {
            switch self {
            case .busy: "我开始认真工作了。"
            case .cpuCritical: "我的脑子要爆炸了。"
            case .cpuRecovery: "呼……终于安静了。"
            case .memoryPressure: "我的胃快撑爆了。"
            case .lowBattery: "我只剩一点力气了……"
            case .sleeping: "让我安静待一会儿。"
            default: "今天挺轻松。"
            }
        }
    }
    let fixture: Fixture
    func snapshot(now: Date) -> AppSnapshot {
        let stale = fixture == .staleOffline
        let failed = fixture == .requestFailed
        let codexFive = QuotaWindow(usedPercent: fixture == .zeroUsage ? 0 : fixture == .quota95 ? 95 : 62,
            durationMinutes: 300, resetsAt: now.addingTimeInterval(8280))!
        let codexWeek = QuotaWindow(usedPercent: 31, durationMinutes: 10080,
            resetsAt: now.addingTimeInterval(367200))!
        let claudeFive = QuotaWindow(usedPercent: 81, durationMinutes: 300,
            resetsAt: now.addingTimeInterval(3960))!
        let claudeWeek = QuotaWindow(usedPercent: fixture == .zeroUsage ? 0 : fixture == .quota95 ? 95 : 47,
            durationMinutes: 10080, resetsAt: now.addingTimeInterval(302400))!
        let codexFiveState: QuotaWindowState = switch fixture {
        case .codexWeeklyOnly: .notApplicable
        case .codexUnreported: .unreported
        case .requestFailed: .requestFailed
        default: .available(codexFive)
        }
        let claudeFiveState: QuotaWindowState = switch fixture {
        case .claudeWeeklyOnly: .notApplicable
        case .requestFailed: .requestFailed
        default: .available(claudeFive)
        }
        let source = failed ? "Bundled failure fixture" : "Bundled fixture"
        let sampledAt: Date? = failed ? nil : stale ? now.addingTimeInterval(-600) : now
        let freshness: Freshness = failed ? .unavailable : stale ? .stale : .fresh
        let codex = QuotaItem(provider: .codex,
            fiveHour: codexFiveState,
            weekly: failed ? .requestFailed : .available(codexWeek),
            sampledAt: sampledAt, source: source, freshness: freshness, mode: .mock)
        let claude = QuotaItem(provider: .claude,
            fiveHour: claudeFiveState,
            weekly: failed ? .requestFailed : fixture == .claudeUnreported ? .unreported : .available(claudeWeek),
            sampledAt: sampledAt, source: source, freshness: freshness, mode: .mock)
        let cpu: Double = switch fixture {
        case .busy: 72
        case .cpuCritical: 96
        case .cpuRecovery: 20
        case .sleeping: 5
        default: 32
        }
        let battery: Double? = switch fixture {
        case .lowBattery: 4
        case .noBattery: nil
        default: 78
        }
        return AppSnapshot(mode: .mock, soulVisual: fixture.soulVisual, soulMood: fixture.soulMood,
            soulMessage: fixture.soulMessage, cpu: PercentMetric(usedPercent: cpu),
            memoryUsed: PercentMetric(usedPercent: 54), memoryPressure: fixture == .memoryPressure ? "Critical · Mock" : "Normal · Mock",
            disk: PercentMetric(usedPercent: 67), battery: PercentMetric(usedPercent: battery),
            publicIP: stale ? nil : "203.0.113.42", region: stale ? nil : "Example region",
            proxyHint: "Unknown · Mock", tunnelHint: "Unknown · Mock", quotas: [codex, claude],
            runtimes: [RuntimeItem(name: "Java", version: "21 · Mock"), RuntimeItem(name: "Node", version: "18 · Mock")],
            ports: [PortItem(port: 8080, process: "Example process · Mock")], cleanerItems: [], serviceLatency: [])
    }
}
// Explicit composition boundary; Phase A never starts live collection.
struct UnavailableProvider: SnapshotProvider {
    func snapshot(now: Date) -> AppSnapshot {
        let empty = QuotaProvider.allCases.map { QuotaItem(provider: $0, fiveHour: .providerUnavailable, weekly: .providerUnavailable, sampledAt: nil, source: "No live provider", freshness: .unavailable, mode: .live) }
        return AppSnapshot(mode: .live, soulVisual: nil, soulMood: "Unavailable", soulMessage: "No live provider",
            cpu: PercentMetric(usedPercent: nil), memoryUsed: PercentMetric(usedPercent: nil), memoryPressure: "Unknown",
            disk: PercentMetric(usedPercent: nil), battery: PercentMetric(usedPercent: nil), publicIP: nil, region: nil,
            proxyHint: "Unknown", tunnelHint: "Unknown", quotas: empty, runtimes: [], ports: [], cleanerItems: [], serviceLatency: [])
    }
}
@MainActor final class AppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot
    @Published private(set) var previewFixture: MockProvider.Fixture?
    @Published private(set) var systemMode: SystemMode = .preview
    @Published private(set) var displayNow: Date
    private var provider: any SnapshotProvider
    private var clockSubscription: AnyCancellable?
    private var lifecycleSubscriptions: Set<AnyCancellable> = []
    private var visibleWindows: Set<UUID> = []
    private var visibleSystemWindows: Set<UUID> = []
    private var visibleDevWindows: Set<UUID> = []
    private var sleeping = false
    private var terminating = false
    @Published private(set) var connectivityEnabled: Bool
    private let networkPath: (any NetworkPathProviding)?
    private let networkHTTP: any NetworkHTTPClient
    private let networkLocal: any LocalNetworkProviding
    private lazy var networkMonitor = NetworkMonitor(path: networkPath, client: networkHTTP, local: networkLocal,
        onSnapshot: { [weak self] value in
            guard let self, self.systemMode == .live, !self.sleeping, !self.terminating else { return }
            var current = self.snapshot
            current.network = value
            self.snapshot = current
        })
    private let cleanerScanner: CleanerScanner
    private let cleanerDescriptors: [CleanerDescriptor]
    private lazy var cleanerSession = CleanerSession(scanner: cleanerScanner, descriptors: cleanerDescriptors) { [weak self] value in
        guard let self, self.systemMode == .live, !self.sleeping, !self.terminating else { return }
        var current = self.snapshot
        current.cleaner = value
        self.snapshot = current
    }
    @Published private(set) var cleanerPreviewDestination: CleanerPreviewDestination?
    @Published private(set) var cleanerPreview: CleanerPreviewSnapshot?
    private let cleanerPreviewScanner: CleanerPreviewScanner
    private lazy var cleanerPreviewSession = CleanerPreviewSession(scanner: cleanerPreviewScanner) { [weak self] value in
        guard let self, self.cleanerPreviewDestination != nil, self.systemMode == .live else { return }
        self.cleanerPreview = value
    }
    var cleanerPreviewRunning: Bool { cleanerPreviewSession.isRunning }
    var cleanerRunning: Bool { cleanerSession.isRunning }
    func scanCleaner() {
        if systemMode == .live && !sleeping && !terminating && !cleanerPreviewRunning && cleanerPreviewDestination == nil { cleanerSession.start() }
    }
    func openCleanerPreview(_ category: CleanerCategory) {
        guard systemMode == .live, !sleeping, !terminating, !cleanerRunning,
              snapshot.cleaner.categories.contains(category), CleanerPreviewBoundary.resolvedRoot(for: category) != nil else { return }
        cleanerPreviewDestination = .directory(category)
        cleanerPreviewSession.open(category)
    }
    func openDockerPreview() {
        guard systemMode == .live, !sleeping, !terminating, !cleanerRunning, let value = snapshot.cleaner.docker else { return }
        cleanerPreviewSession.close(); cleanerPreview = nil
        cleanerPreviewDestination = .docker(value) // shared logical rows only, never a filesystem/CLI query
    }
    func enterCleanerPreview(_ item: CleanerPreviewItem) { cleanerPreviewSession.enter(item) }
    func backCleanerPreview(to depth: Int? = nil) { cleanerPreviewSession.back(to: depth) }
    func sortCleanerPreview(_ order: CleanerPreviewSort) { cleanerPreviewSession.sort(order) }
    func cancelCleanerPreview() { cleanerPreviewSession.cancel() }
    func closeCleanerPreview() {
        cleanerPreviewSession.close(); cleanerPreviewDestination = nil; cleanerPreview = nil
    }
    func waitForCleanerPreviewStop() async { await cleanerPreviewSession.waitForStop() }
    func cancelCleaner() { cleanerSession.cancel() }
    func waitForCleanerStop() async { await cleanerSession.waitForStop() }

    var networkStarts: Int { networkMonitor.starts }
    private let codexQuota: any LiveQuotaProviding
    private let claudeQuota: any LiveQuotaProviding
    private let quotaClock: any QuotaClock
    @Published private(set) var quotaAlertEvents: [QuotaAlertEvent] = []
    private lazy var aiQuotaMonitor = AIQuotaMonitor(codex: codexQuota, claude: claudeQuota, clock: quotaClock) { [weak self] value, alerts in
        guard let self, self.systemMode == .live, !self.sleeping, !self.terminating else { return }
        var current = self.snapshot
        current.quotas = value.items
        current.quotaDetails = value.details
        current.quotaMode = .live
        self.snapshot = current
        self.quotaAlertEvents = Array((self.quotaAlertEvents + alerts).suffix(16)) // bounded event output; no notification permission requested
    }
    var quotaStarts: Int { aiQuotaMonitor.starts }
    func waitForQuotaStop() async { await aiQuotaMonitor.waitForStop() }
    func stopQuotaForTermination() async {
        stopForTermination()
        await waitForCollectorsToStop()
    }
    func stopForTermination() {
        guard !terminating else { return }
        terminating = true
        clockSubscription?.cancel(); clockSubscription = nil
        lifecycleSubscriptions.removeAll()
        sensorHub.stop(); devMonitor.stop(); networkMonitor.stop(); aiQuotaMonitor.stop()
        cleanerSession.suspend(); closeCleanerPreview(); quotaAlertEvents = []
    }
    func waitForCollectorsToStop() async {
        await sensorHub.waitForStop(); await devMonitor.waitForStop()
        await networkMonitor.waitForStop(); await aiQuotaMonitor.waitForStop()
        await cleanerSession.waitForStop(); await cleanerPreviewSession.waitForStop()
    }

    private let sensorSampler: any SystemSampling
    private let detailSampler: any SystemDetailSampling
    private lazy var sensorHub = SensorHub(sampler: sensorSampler, details: detailSampler,
        onReading: { [weak self] reading, soul in self?.applyLive(reading: reading, soul: soul) },
        onDetails: { [weak self] update in self?.applyDetail(update) })
    private let devRuntimes: RuntimeDetector
    private let devPorts: PortDetector
    private lazy var devMonitor = DevMonitor(runtimes: devRuntimes, ports: devPorts,
        onRuntimes: { [weak self] reading in self?.applyDevRuntimes(reading) },
        onPorts: { [weak self] reading in self?.applyDevPorts(reading) })
    var sensorStarts: Int { sensorHub.starts }
    var sensorInterval: TimeInterval { sensorHub.samplingInterval }
    var devStarts: Int { devMonitor.starts }
    var devPortInterval: TimeInterval { devMonitor.portInterval }
    var systemSamplingTier: SamplingTier { sensorHub.samplingTier }
    var devSamplingTier: SamplingTier { devMonitor.samplingTier }
    var collectorsRunning: (system: Bool, dev: Bool, network: Bool, quota: Bool) {
        (sensorHub.isRunning, devMonitor.isRunning, networkMonitor.isRunning, aiQuotaMonitor.isRunning)
    }

    init(provider: any SnapshotProvider = MockProvider(fixture: .healthy),
         sampler: any SystemSampling = NativeSystemSampler(),
         details: any SystemDetailSampling = NativeSystemDetailSampler(),
         devRuntimes: RuntimeDetector = RuntimeDetector(), devPorts: PortDetector = PortDetector(),
         networkPath: (any NetworkPathProviding)? = nil,
         networkHTTP: any NetworkHTTPClient = EphemeralNetworkHTTPClient(),
         networkLocal: any LocalNetworkProviding = NativeLocalNetworkProvider(),
         cleanerScanner: CleanerScanner = CleanerScanner(locator: CleanerLocator(), docker: DockerCleanerAdapter()),
         cleanerCategories: [CleanerDescriptor] = CleanerCatalog.categories(),
         cleanerPreviewScanner: CleanerPreviewScanner = CleanerPreviewScanner(),
         codexQuota: (any LiveQuotaProviding)? = nil, claudeQuota: (any LiveQuotaProviding)? = nil,
         quotaClock: any QuotaClock = SystemQuotaClock(), now: Date = Date()) {
        self.codexQuota = codexQuota ?? CodexQuotaProvider()
        self.devRuntimes = devRuntimes; self.devPorts = devPorts
        self.claudeQuota = claudeQuota ?? ClaudeQuotaProvider()
        self.quotaClock = quotaClock
        self.cleanerPreviewScanner = cleanerPreviewScanner
        self.cleanerScanner = cleanerScanner; self.cleanerDescriptors = cleanerCategories
        self.provider = provider
        self.networkPath = networkPath; self.networkHTTP = networkHTTP; self.networkLocal = networkLocal
        connectivityEnabled = UserDefaults.standard.object(forKey: "macsoul.connectivityEnabled") as? Bool ?? true
        sensorSampler = sampler
        detailSampler = details
        previewFixture = (provider as? MockProvider)?.fixture
        displayNow = now
        snapshot = provider.snapshot(now: now)
        updateSamplingPolicy()
        clockSubscription = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                Task { @MainActor in self?.advanceDisplayClock(now: date) }
            }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.suspendForSleep() } }
            .store(in: &lifecycleSubscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.resumeAfterWake() } }
            .store(in: &lifecycleSubscriptions)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.stopForTermination() } }
            .store(in: &lifecycleSubscriptions)
    }
    func advanceDisplayClock(now: Date) { displayNow = now }
    func refresh(now: Date = Date()) {
        var replacement = provider.snapshot(now: now)
        if systemMode == .live {
            replacement.cleaner = snapshot.cleaner.mode == .live ? snapshot.cleaner : .live(categories: cleanerDescriptors)
            let quota = snapshot.quotaMode == .live && !sleeping
                ? AIQuotaSnapshot(items: snapshot.quotas, details: snapshot.quotaDetails) : .stopped
            replacement.quotaMode = .live
            replacement.quotas = quota.items
            replacement.quotaDetails = quota.details
            replacement.systemMode = .live
            replacement.devMode = .live
            replacement.networkMode = .live
            replacement.publicIP = nil; replacement.region = nil
            replacement.proxyHint = "Unavailable"; replacement.tunnelHint = "Unavailable"
            replacement.network = NetworkSnapshot()
            replacement.network.probesEnabled = connectivityEnabled
            replacement.network.probes = ProbeService.allCases.map {
                ProbeReading(service: $0, state: connectivityEnabled ? .checking : .disabled)
            }
            replacement.runtimes = []
            replacement.ports = []
            replacement.runtimeReading = .sampling
            replacement.portReading = .sampling
            replacement.cpu = PercentMetric(usedPercent: nil)
            replacement.memoryUsed = PercentMetric(usedPercent: nil)
            replacement.memoryPressure = MemoryPressureLevel.unknown.liveLabel
            replacement.disk = PercentMetric(usedPercent: nil)
            replacement.battery = PercentMetric(usedPercent: nil)
            replacement.diskReading = .unknown
            replacement.batteryReading = .unknown
            replacement.processReading = .unknown
            replacement.soulVisual = .normal
            replacement.soulMood = "Observing · Live"
            replacement.soulMessage = "Waiting for a valid system sample."
        }
        snapshot = replacement
        displayNow = now
    }

    func setSystemMode(_ mode: SystemMode) {
        guard !terminating, mode != systemMode else { return }
        if mode == .preview { cleanerSession.resetForPreview(); closeCleanerPreview(); aiQuotaMonitor.stop(); quotaAlertEvents = [] }
        systemMode = mode
        refresh()
        if mode == .live && !sleeping { sensorHub.start(); devMonitor.start(); networkMonitor.start(probesEnabled: connectivityEnabled); aiQuotaMonitor.start() }
        else { sensorHub.stop(); devMonitor.stop(); networkMonitor.stop() }
    }

    func setWindow(_ id: UUID, visible: Bool, section: AppSection) {
        visibleSystemWindows.remove(id)
        visibleDevWindows.remove(id)
        if visible {
            visibleWindows.insert(id)
            if section == .system { visibleSystemWindows.insert(id) }
            if section == .dev { visibleDevWindows.insert(id) }
        } else {
            visibleWindows.remove(id)
            visibleSystemWindows.remove(id)
            visibleDevWindows.remove(id)
        }
        updateSamplingPolicy()
    }

    func setWindowSection(_ id: UUID, section: AppSection) {
        guard visibleWindows.contains(id) else { return }
        if section == .system { visibleSystemWindows.insert(id) }
        else { visibleSystemWindows.remove(id) }
        if section == .dev { visibleDevWindows.insert(id) }
        else { visibleDevWindows.remove(id) }
        updateSamplingPolicy()
    }

    private func updateSamplingPolicy() {
        sensorHub.samplingTier = .resolve(mainVisible: !visibleWindows.isEmpty, relevantVisible: !visibleSystemWindows.isEmpty)
        devMonitor.samplingTier = .resolve(mainVisible: !visibleWindows.isEmpty, relevantVisible: !visibleDevWindows.isEmpty)
    }

    func setConnectivityEnabled(_ enabled: Bool) {
        guard enabled != connectivityEnabled else { return }
        connectivityEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "macsoul.connectivityEnabled")
        networkMonitor.setProbesEnabled(enabled)
    }
    func refreshNetwork() { if systemMode == .live && !sleeping { networkMonitor.refresh() } }

    func refreshDev() { if systemMode == .live && !sleeping { devMonitor.refresh() } }

    private func applyDevRuntimes(_ reading: RuntimeReading) {
        guard systemMode == .live && !sleeping && !terminating else { return }
        var current = snapshot
        current.runtimeReading = reading
        snapshot = current
    }

    private func applyDevPorts(_ reading: PortReading) {
        guard systemMode == .live && !sleeping && !terminating else { return }
        var current = snapshot
        current.portReading = reading
        snapshot = current
    }

    private func applyLive(reading: SystemReading, soul: SoulStatus) {
        guard systemMode == .live && !sleeping && !terminating else { return }
        var current = snapshot
        current.cpu = PercentMetric(usedPercent: reading.cpuPercent)
        current.memoryUsed = PercentMetric(usedPercent: reading.memory?.usedPercent)
        current.memoryBytes = reading.memory
        current.memoryPressure = reading.pressure.liveLabel
        current.soulVisual = soul.visual
        current.soulMood = soul.mood
        current.soulMessage = soul.message
        snapshot = current
    }

    private func applyDetail(_ update: SystemDetailUpdate) {
        guard systemMode == .live && !sleeping && !terminating else { return }
        var current = snapshot
        switch update {
        case .disk(let reading):
            current.diskReading = reading
            if case .available(let usage, _) = reading {
                current.disk = PercentMetric(usedPercent: usage.usedPercent)
            } else {
                current.disk = PercentMetric(usedPercent: nil)
            }
        case .battery(let reading):
            current.batteryReading = reading
            if case .present(let status, _) = reading {
                current.battery = PercentMetric(usedPercent: Double(status.chargePercent))
            } else {
                current.battery = PercentMetric(usedPercent: nil)
            }
        case .processes(let reading):
            current.processReading = reading
        }
        snapshot = current
    }

    func suspendForSleep() {
        guard !sleeping, !terminating else { return }
        closeCleanerPreview()
        cleanerSession.suspend()
        sleeping = true
        sensorHub.stop()
        devMonitor.stop()
        networkMonitor.stop()
        aiQuotaMonitor.stop(); quotaAlertEvents = []
        if systemMode == .live { refresh() }
    }

    func resumeAfterWake() {
        guard sleeping, !terminating else { return }
        sleeping = false
        if systemMode == .live { sensorHub.start(); devMonitor.start(); networkMonitor.start(probesEnabled: connectivityEnabled); aiQuotaMonitor.start() }
    }
    #if DEBUG
    func selectPreviewFixture(_ fixture: MockProvider.Fixture, now: Date = Date()) {
        guard previewFixture != nil else { return }
        previewFixture = fixture
        provider = MockProvider(fixture: fixture)
        refresh(now: now)
    }
    #endif
}
