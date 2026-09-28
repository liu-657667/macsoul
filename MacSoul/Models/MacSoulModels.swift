import Foundation

enum DataMode: String { case mock = "MOCK", live = "LIVE" }
enum Freshness: String { case fresh = "Fresh", stale = "Stale", unavailable = "Unavailable" }
enum SoulVisual: String, CaseIterable {
    case normal, busy, overload, bloated, lowBattery, sleeping

    var assetName: String {
        switch self {
        case .normal: "MacSoulNormal"
        case .busy: "MacSoulBusy"
        case .overload: "MacSoulOverload"
        case .bloated: "MacSoulBloated"
        case .lowBattery: "MacSoulLowBattery"
        case .sleeping: "MacSoulSleeping"
        }
    }
}
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
enum QuotaWindowKind: String, CaseIterable, Identifiable {
    case fiveHour, weekly
    var id: Self { self }
    var label: String { self == .fiveHour ? "5h" : "1 week" }
}
enum QuotaWindowState: Equatable {
    case available(QuotaWindow)
    case notApplicable
    case unreported
    case requestFailed
    case providerUnavailable
}
enum QuotaDisplayState: Equatable {
    case fresh(QuotaWindow)
    case stale(QuotaWindow)
    case unreported
    case requestFailed
    case providerUnavailable

    var value: QuotaWindow? {
        switch self {
        case .fresh(let window), .stale(let window): window
        default: nil
        }
    }
}
struct QuotaDisplayWindow: Identifiable, Equatable {
    let kind: QuotaWindowKind
    let state: QuotaDisplayState
    var id: QuotaWindowKind { kind }
}
struct QuotaItem: Identifiable, Equatable {
    let provider: QuotaProvider
    let fiveHour: QuotaWindowState
    let weekly: QuotaWindowState
    let sampledAt: Date?
    let source: String
    let freshness: Freshness
    let mode: DataMode
    var id: String { provider.id }

    func state(for kind: QuotaWindowKind) -> QuotaWindowState {
        kind == .fiveHour ? fiveHour : weekly
    }

    func displayWindows(now: Date) -> [QuotaDisplayWindow] {
        QuotaWindowKind.allCases.compactMap { kind in
            let display: QuotaDisplayState
            switch state(for: kind) {
            case .notApplicable:
                return nil
            case .unreported:
                display = .unreported
            case .requestFailed:
                display = .requestFailed
            case .providerUnavailable:
                display = .providerUnavailable
            case .available(let window):
                let oldSample = sampledAt.map { now.timeIntervalSince($0) > 300 } ?? true
                let expiredReset = window.resetsAt.map { $0 <= now } ?? false
                display = freshness == .fresh && !oldSample && !expiredReset
                    ? .fresh(window) : .stale(window)
            }
            return QuotaDisplayWindow(kind: kind, state: display)
        }
    }

    func notApplicableLabels() -> [String] {
        QuotaWindowKind.allCases.compactMap { kind in
            state(for: kind) == .notApplicable ? kind.label : nil
        }
    }

    // The future alert/Soul engine may consume only these fresh, applicable values.
    func alertEligibleWindows(now: Date, threshold: Double = 95) -> [QuotaWindowKind] {
        guard threshold.isFinite, (0...100).contains(threshold) else { return [] }
        return displayWindows(now: now).compactMap { item in
            guard case .fresh(let window) = item.state, window.usedPercent >= threshold else { return nil }
            return item.kind
        }
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
struct PortItem: Identifiable, Hashable {
    let port: Int
    let process: String
    var id: Int { port }
    // Ports are identifiers, so locale-aware number grouping must not apply.
    var displayPort: String { String(port) }
}
struct AppSnapshot {
    let mode: DataMode
    let soulVisual: SoulVisual?
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
