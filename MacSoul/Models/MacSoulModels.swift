import Foundation

enum DataMode: String { case mock = "MOCK", live = "LIVE" }
enum Freshness: String { case fresh = "Fresh", stale = "Stale", unavailable = "Unavailable" }
enum QuotaProvider: String, CaseIterable, Identifiable {
    case codex = "Codex", claude = "Claude Code"
    var id: String { rawValue }
}
struct QuotaWindow: Equatable {
    let usedPercent: Double // 0...100
    let durationMinutes: Int
    let resetsAt: Date?
    init?(usedPercent: Double, durationMinutes: Int, resetsAt: Date?) {
        guard usedPercent.isFinite, (0...100).contains(usedPercent), durationMinutes > 0 else { return nil }
        self.usedPercent = usedPercent; self.durationMinutes = durationMinutes; self.resetsAt = resetsAt
    }
}
struct QuotaItem: Identifiable, Equatable {
    let provider: QuotaProvider
    let fiveHour: QuotaWindow?
    let weekly: QuotaWindow?
    let sampledAt: Date?
    let source: String
    let freshness: Freshness
    let mode: DataMode
    var id: String { provider.id }
    func effectiveFreshness(now: Date) -> Freshness {
        guard freshness != .unavailable else { return .unavailable }
        guard let sampledAt, now.timeIntervalSince(sampledAt) <= 300 else { return .stale }
        if [fiveHour, weekly].compactMap({ $0 }).contains(where: { $0.resetsAt.map { $0 <= now } ?? false }) { return .stale }
        return freshness
    }
}
struct PercentMetric: Equatable {
    let usedPercent: Double?
    var label: String { usedPercent.map { "\(Int($0.rounded()))%" } ?? "—" }
    var progress: Double? { usedPercent.map { min(max($0 / 100, 0), 1) } }
}
struct RuntimeItem: Identifiable, Hashable { let name: String; let version: String; var id: String { name } }
struct CleanerItem: Identifiable, Hashable {
    enum Risk: String { case safe = "SAFE", caution = "CAUTION", dangerous = "DANGEROUS" }
    let name: String; let size: String; let risk: Risk
    var id: String { name }
}
struct PortItem: Identifiable, Hashable { let port: Int; let process: String; var id: Int { port } }
struct AppSnapshot {
    let mode: DataMode
    let soulMood: String
    let soulMessage: String
    let cpu: PercentMetric
    let memoryUsed: PercentMetric
    let memoryPressure: String
    let disk: PercentMetric
    let battery: PercentMetric
    let publicIP: String?
    let region: String?
    let proxyHint: String
    let tunnelHint: String
    let quotas: [QuotaItem]
    let runtimes: [RuntimeItem]
    let ports: [PortItem]
    let cleanerItems: [CleanerItem]
    let serviceLatency: [(String, String)]
}
