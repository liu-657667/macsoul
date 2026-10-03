import Foundation
import CoreFoundation

enum QuotaConnectionState: String, Equatable {
    case connecting, available, reconnecting, unavailable, malformed, stopped
}
enum ClaudeQuotaCapability: String, Equatable {
    case notInstalled, detectedUnauthenticated, detectedNoSubscriptionQuota
    case available, requestFailed, unsupportedVersion, noVerifiedSource
}
struct QuotaProviderDetail: Equatable {
    let provider: QuotaProvider
    var connection: QuotaConnectionState
    var claudeCapability: ClaudeQuotaCapability? = nil
    var version: String? = nil
    var authorizationRequired = false
}
struct AIQuotaSnapshot: Equatable {
    var items: [QuotaItem]
    var details: [QuotaProviderDetail]

    static var stopped: Self {
        Self(items: QuotaProvider.allCases.map { .unavailable($0) },
             details: QuotaProvider.allCases.map { QuotaProviderDetail(provider: $0, connection: .stopped) })
    }
}
extension QuotaItem {
    static func unavailable(_ provider: QuotaProvider, failed: Bool = false) -> Self {
        Self(provider: provider, fiveHour: failed ? .requestFailed : .providerUnavailable,
             weekly: failed ? .requestFailed : .providerUnavailable, sampledAt: nil,
             source: provider == .codex ? "Codex App Server" : "Claude Code status line",
             freshness: .unavailable, mode: .live)
    }
    var entirelyUnavailable: Bool { fiveHour == .providerUnavailable && weekly == .providerUnavailable }
    var badge: String { mode == .mock ? "MOCK" : entirelyUnavailable ? "UNAVAILABLE" : "LIVE" }
}

enum QuotaParseError: Error, Equatable { case malformed, ambiguousBucket, duplicateWindow }

// Strict numeric validation: JSON booleans/strings are never telemetry. Nothing is clamped.
enum QuotaWireValue {
    static func number(_ raw: Any?) throws -> Double {
        guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else { throw QuotaParseError.malformed }
        return value.doubleValue
    }
    static func percent(_ raw: Any?) throws -> Double {
        let value = try number(raw)
        guard (0...100).contains(value) else { throw QuotaParseError.malformed }
        return value
    }
    static func reset(_ raw: Any?) throws -> Date? {
        guard let raw, !(raw is NSNull) else { return nil }
        let seconds = try number(raw)
        // Foundation can represent more, but the source must be a plausible epoch timestamp.
        guard seconds > 0, seconds.rounded() == seconds, seconds < 253_402_300_800 else { throw QuotaParseError.malformed }
        return Date(timeIntervalSince1970: seconds)
    }
}

// Only the selected rate-limit bucket's typed plan semantics are examined. No profile read.
// Verified against OpenAI rust-v0.160.0 PlanType and the current Pro no-five-hour policy.
// Unknown/future values and workspace variants stay conservative, never substring matched.
enum CodexPlanSemantics {
    case unknown, plus, pro
    init(wireValue: Any?) {
        switch wireValue as? String {
        case "plus": self = .plus
        case "pro", "prolite", "promax": self = .pro
        default: self = .unknown
        }
    }
}

// primary/secondary are unordered containers; their durations determine their meanings.
enum CodexQuotaParser {
    static func parse(_ payload: [String: Any], now: Date) throws -> QuotaItem {
        guard let bucket = try selectBucket(payload) else {
            return item(five: .unreported, week: .unreported, now: now)
        }
        var mapped: [QuotaWindowKind: QuotaWindowState] = [:]
        for key in ["primary", "secondary"] {
            guard let raw = bucket[key], !(raw is NSNull) else { continue }
            guard let value = raw as? [String: Any] else { throw QuotaParseError.malformed }
            let duration = try QuotaWireValue.number(value["windowDurationMins"])
            guard duration > 0, duration.rounded() == duration, duration <= Double(Int32.max) else {
                throw QuotaParseError.malformed
            }
            let kind: QuotaWindowKind
            if abs(duration - 300) <= 1 { kind = .fiveHour }
            else if abs(duration - 10080) <= 1 { kind = .weekly }
            else { continue } // Unknown windows cannot invalidate an unrelated recognized window.
            if mapped[kind] != nil {
                mapped[kind] = .requestFailed // Do not arbitrarily choose first/last duplicate.
                continue
            }
            do {
                let used = try QuotaWireValue.percent(value["usedPercent"])
                let reset = try QuotaWireValue.reset(value["resetsAt"])
                guard let window = QuotaWindow(usedPercent: used, durationMinutes: Int(duration), resetsAt: reset) else {
                    throw QuotaParseError.malformed
                }
                mapped[kind] = .available(window)
            } catch { mapped[kind] = .requestFailed }
        }
        // A real reported 300-minute window (including an invalid one) always wins over policy.
        let absentFive: QuotaWindowState = CodexPlanSemantics(wireValue: bucket["planType"]) == .pro
            ? .notApplicable : .unreported
        return item(five: mapped[.fiveHour] ?? absentFive, week: mapped[.weekly] ?? .unreported, now: now)
    }

    private static func selectBucket(_ payload: [String: Any]) throws -> [String: Any]? {
        var unidentifiedBuckets = false
        if let raw = payload["rateLimitsByLimitId"], !(raw is NSNull) {
            guard let buckets = raw as? [String: Any] else { throw QuotaParseError.malformed }
            if let rawCodex = buckets["codex"] {
                guard let codex = rawCodex as? [String: Any] else { throw QuotaParseError.malformed }
                try validateID(codex)
                return codex
            }
            let identified = buckets.values.compactMap { $0 as? [String: Any] }.filter { $0["limitId"] as? String == "codex" }
            guard identified.count <= 1 else { throw QuotaParseError.ambiguousBucket }
            if let codex = identified.first { return codex } // Unique explicit identity, not map order.
            unidentifiedBuckets = !buckets.isEmpty
        }
        if let raw = payload["rateLimits"], !(raw is NSNull) {
            guard let legacy = raw as? [String: Any] else { throw QuotaParseError.malformed }
            try validateID(legacy)
            return legacy // Documented backward-compatible view, not another bucket to add.
        }
        if unidentifiedBuckets { throw QuotaParseError.ambiguousBucket }
        guard payload.keys.contains("rateLimits") || payload.keys.contains("rateLimitsByLimitId") else {
            throw QuotaParseError.malformed
        }
        return nil
    }
    private static func validateID(_ bucket: [String: Any]) throws {
        guard let raw = bucket["limitId"], !(raw is NSNull) else { return }
        guard let id = raw as? String, id == "codex" else { throw QuotaParseError.ambiguousBucket }
    }
    private static func item(five: QuotaWindowState, week: QuotaWindowState, now: Date) -> QuotaItem {
        QuotaItem(provider: .codex, fiveHour: five, weekly: week, sampledAt: now,
                  source: "Codex App Server", freshness: .fresh, mode: .live)
    }
}

// Only sanitized rate-limit fields are accepted by this boundary, never a full status-line payload.
// No bridge/config is installed in this phase. The actual installed capability is unverified.
enum ClaudeQuotaParser {
    static func parse(_ limits: [String: Any], sampledAt: Date) throws -> QuotaItem {
        func window(_ key: String, minutes: Int) throws -> QuotaWindowState {
            guard let raw = limits[key], !(raw is NSNull) else { return .unreported }
            guard let value = raw as? [String: Any] else { throw QuotaParseError.malformed }
            let used = try QuotaWireValue.percent(value["used_percentage"])
            let reset = try QuotaWireValue.reset(value["resets_at"])
            guard let window = QuotaWindow(usedPercent: used, durationMinutes: minutes, resetsAt: reset) else {
                throw QuotaParseError.malformed
            }
            return .available(window)
        }
        return try QuotaItem(provider: .claude, fiveHour: window("five_hour", minutes: 300),
            weekly: window("seven_day", minutes: 10080), sampledAt: sampledAt,
            source: "Claude Code status line", freshness: .fresh, mode: .live)
    }
}

struct QuotaAlertEvent: Equatable {
    let provider: QuotaProvider
    let kind: QuotaWindowKind
    let reset: Date
    let usedPercent: Double
    var soulCopy: String { "AI partner energy is running low." }
}
final class QuotaAlertEngine {
    private struct Key: Hashable { let provider: String; let window: String; let reset: Date }
    private var announced = Set<Key>()
    func evaluate(_ items: [QuotaItem], now: Date) -> [QuotaAlertEvent] {
        var events: [QuotaAlertEvent] = []
        for item in items where item.mode == .live {
            for row in item.displayWindows(now: now) {
                guard case .fresh(let value) = row.state, value.usedPercent >= 95,
                      let reset = value.resetsAt else { continue }
                let key = Key(provider: item.provider.id, window: row.kind.rawValue, reset: reset)
                if announced.insert(key).inserted {
                    events.append(QuotaAlertEvent(provider: item.provider, kind: row.kind,
                                                 reset: reset, usedPercent: value.usedPercent))
                }
            }
        }
        // Past windows cannot be fresh again. Keep active identities across provider restarts/sleep.
        announced = announced.filter { $0.reset > now }
        return events
    }
}

protocol QuotaClock: Sendable {
    func now() -> Date
    func sleep(seconds: TimeInterval) async throws
}
struct SystemQuotaClock: QuotaClock {
    func now() -> Date { Date() }
    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
struct QuotaBackoff {
    private(set) var failures = 0
    mutating func next() -> TimeInterval {
        let steps: [TimeInterval] = [1, 2, 5, 10, 30, 60]
        let delay = steps[min(failures, steps.count - 1)]
        failures = min(failures + 1, steps.count - 1)
        return delay
    }
    mutating func reset() { failures = 0 }
}
