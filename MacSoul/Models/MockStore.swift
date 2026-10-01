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
    private let sensorSampler: any SystemSampling
    private let detailSampler: any SystemDetailSampling
    private lazy var sensorHub = SensorHub(sampler: sensorSampler, details: detailSampler,
        onReading: { [weak self] reading, soul in self?.applyLive(reading: reading, soul: soul) },
        onDetails: { [weak self] update in self?.applyDetail(update) })
    private lazy var devMonitor = DevMonitor(
        onRuntimes: { [weak self] reading in self?.applyDevRuntimes(reading) },
        onPorts: { [weak self] reading in self?.applyDevPorts(reading) })
    var sensorStarts: Int { sensorHub.starts }
    var sensorInterval: TimeInterval { sensorHub.samplingInterval }
    var devStarts: Int { devMonitor.starts }
    var devPortInterval: TimeInterval { devMonitor.portInterval }

    init(provider: any SnapshotProvider = MockProvider(fixture: .healthy),
         sampler: any SystemSampling = NativeSystemSampler(),
         details: any SystemDetailSampling = NativeSystemDetailSampler(), now: Date = Date()) {
        self.provider = provider
        sensorSampler = sampler
        detailSampler = details
        previewFixture = (provider as? MockProvider)?.fixture
        displayNow = now
        snapshot = provider.snapshot(now: now)
        clockSubscription = Timer.publish(every: 30, on: .main, in: .common)
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
    }
    func advanceDisplayClock(now: Date) { displayNow = now }
    func refresh(now: Date = Date()) {
        var replacement = provider.snapshot(now: now)
        if systemMode == .live {
            replacement.systemMode = .live
            replacement.devMode = .live
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
        guard mode != systemMode else { return }
        systemMode = mode
        refresh()
        if mode == .live && !sleeping { sensorHub.start(); devMonitor.start() }
        else { sensorHub.stop(); devMonitor.stop() }
    }

    func setWindow(_ id: UUID, visible: Bool, section: AppSection) {
        if visible {
            visibleWindows.insert(id)
            if section == .system { visibleSystemWindows.insert(id) }
            if section == .dev { visibleDevWindows.insert(id) }
        } else {
            visibleWindows.remove(id)
            visibleSystemWindows.remove(id)
            visibleDevWindows.remove(id)
        }
        sensorHub.systemPageVisible = !visibleSystemWindows.isEmpty
        devMonitor.devPageVisible = !visibleDevWindows.isEmpty
    }

    func setWindowSection(_ id: UUID, section: AppSection) {
        guard visibleWindows.contains(id) else { return }
        if section == .system { visibleSystemWindows.insert(id) }
        else { visibleSystemWindows.remove(id) }
        if section == .dev { visibleDevWindows.insert(id) }
        else { visibleDevWindows.remove(id) }
        sensorHub.systemPageVisible = !visibleSystemWindows.isEmpty
        devMonitor.devPageVisible = !visibleDevWindows.isEmpty
    }

    func refreshDev() { if systemMode == .live && !sleeping { devMonitor.refresh() } }

    private func applyDevRuntimes(_ reading: RuntimeReading) {
        guard systemMode == .live && !sleeping else { return }
        var current = snapshot
        current.runtimeReading = reading
        snapshot = current
    }

    private func applyDevPorts(_ reading: PortReading) {
        guard systemMode == .live && !sleeping else { return }
        var current = snapshot
        current.portReading = reading
        snapshot = current
    }

    private func applyLive(reading: SystemReading, soul: SoulStatus) {
        guard systemMode == .live && !sleeping else { return }
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
        guard systemMode == .live && !sleeping else { return }
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

    private func suspendForSleep() {
        sleeping = true
        sensorHub.stop()
        devMonitor.stop()
        if systemMode == .live { refresh() }
    }

    private func resumeAfterWake() {
        sleeping = false
        if systemMode == .live { sensorHub.start(); devMonitor.start() }
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
