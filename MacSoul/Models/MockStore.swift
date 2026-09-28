import Foundation
import Combine

protocol SnapshotProvider { func snapshot(now: Date) -> AppSnapshot }
struct MockProvider: SnapshotProvider {
    enum Fixture: String, CaseIterable { case healthy, cpuCritical, cpuRecovery, memoryPressure, quota95, missingWindow, staleOffline, noBattery }
    let fixture: Fixture
    func snapshot(now: Date) -> AppSnapshot {
        let stale = fixture == .staleOffline
        let codex = QuotaItem(provider: .codex,
            fiveHour: fixture == .missingWindow ? nil : QuotaWindow(usedPercent: fixture == .quota95 ? 95 : 62, durationMinutes: 300, resetsAt: now.addingTimeInterval(8280)),
            weekly: QuotaWindow(usedPercent: 31, durationMinutes: 10080, resetsAt: now.addingTimeInterval(367200)),
            sampledAt: stale ? now.addingTimeInterval(-600) : now, source: "Bundled fixture", freshness: stale ? .stale : .fresh, mode: .mock)
        let claude = QuotaItem(provider: .claude,
            fiveHour: QuotaWindow(usedPercent: 81, durationMinutes: 300, resetsAt: now.addingTimeInterval(3960)),
            weekly: QuotaWindow(usedPercent: 47, durationMinutes: 10080, resetsAt: now.addingTimeInterval(302400)),
            sampledAt: stale ? now.addingTimeInterval(-600) : now, source: "Bundled fixture", freshness: stale ? .stale : .fresh, mode: .mock)
        let cpu = fixture == .cpuCritical ? 96.0 : fixture == .cpuRecovery ? 20.0 : 32.0
        return AppSnapshot(mode: .mock, soulMood: fixture == .cpuCritical ? "Critical · Mock" : "Calm · Mock",
            soulMessage: "演示数据，未连接系统采样", cpu: PercentMetric(usedPercent: cpu),
            memoryUsed: PercentMetric(usedPercent: 54), memoryPressure: fixture == .memoryPressure ? "Critical · Mock" : "Normal · Mock",
            disk: PercentMetric(usedPercent: 67), battery: PercentMetric(usedPercent: fixture == .noBattery ? nil : 78),
            publicIP: stale ? nil : "203.0.113.42", region: stale ? nil : "Example region",
            proxyHint: "Unknown · Mock", tunnelHint: "Unknown · Mock", quotas: [codex, claude],
            runtimes: [RuntimeItem(name: "Java", version: "21 · Mock"), RuntimeItem(name: "Node", version: "18 · Mock")],
            ports: [PortItem(port: 8080, process: "Example process · Mock")], cleanerItems: [], serviceLatency: [])
    }
}
// Explicit composition boundary; Phase A never starts live collection.
struct UnavailableProvider: SnapshotProvider {
    func snapshot(now: Date) -> AppSnapshot {
        let empty = QuotaProvider.allCases.map { QuotaItem(provider: $0, fiveHour: nil, weekly: nil, sampledAt: nil, source: "No live provider", freshness: .unavailable, mode: .live) }
        return AppSnapshot(mode: .live, soulMood: "Unavailable", soulMessage: "No live provider",
            cpu: PercentMetric(usedPercent: nil), memoryUsed: PercentMetric(usedPercent: nil), memoryPressure: "Unknown",
            disk: PercentMetric(usedPercent: nil), battery: PercentMetric(usedPercent: nil), publicIP: nil, region: nil,
            proxyHint: "Unknown", tunnelHint: "Unknown", quotas: empty, runtimes: [], ports: [], cleanerItems: [], serviceLatency: [])
    }
}
@MainActor final class AppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot
    private let provider: any SnapshotProvider
    init(provider: any SnapshotProvider = MockProvider(fixture: .healthy), now: Date = Date()) {
        self.provider = provider; snapshot = provider.snapshot(now: now)
    }
    func refresh(now: Date = Date()) { snapshot = provider.snapshot(now: now) }
}
