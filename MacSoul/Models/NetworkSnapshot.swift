import Foundation
import Darwin

// Structured Live readings never fall back to the legacy Mock display fields.
enum NetworkPathState: String { case sampling = "Monitoring…", satisfied = "Connected", requiresConnection = "Connection required", unsatisfied = "Offline", unavailable = "Unavailable" }
enum NetworkInterfaceKind: String, CaseIterable { case wifi = "Wi-Fi", ethernet = "Ethernet", cellular = "Cellular", loopback = "Loopback", other = "Other" }
struct NetworkPathReading: Equatable {
    var state: NetworkPathState = .sampling
    var interfaces: [NetworkInterfaceKind] = []
    var interfaceNames: [String] = []
    var expensive: Bool? = nil
    var constrained: Bool? = nil
    var supportsIPv4 = false
    var supportsIPv6 = false
    var online: Bool { state == .satisfied }
}

enum NetworkFailure: String, Error, Equatable {
    case timeout = "Timeout", transport = "Transport failed", http = "HTTP failed"
    case malformed = "Invalid response", tooLarge = "Response too large", unavailable = "Unavailable", offline = "Offline"
}
enum IPFamily: CaseIterable { case ipv4, ipv6 }
struct PublicIPReading: Equatable {
    var address: String? = nil
    var sampledAt: Date? = nil
    var attemptedAt: Date? = nil
    var freshness: Freshness = .unavailable
    var failure: NetworkFailure? = nil
    var checking = false
    let source: String
    mutating func apply(_ result: Result<String, NetworkFailure>, at date: Date) {
        attemptedAt = date; checking = false
        switch result {
        case .success(let address):
            self.address = address; sampledAt = date; freshness = .fresh; failure = nil
        case .failure(let failure):
            self.failure = failure; freshness = address == nil ? .unavailable : .stale
        }
    }
    mutating func invalidate(_ failure: NetworkFailure? = nil) {
        checking = false
        freshness = address == nil ? .unavailable : .stale
        self.failure = failure
    }
    func label(now: Date) -> String {
        if let address {
            let expired = sampledAt.map { now.timeIntervalSince($0) >= NetworkSchedule.ipTTL } ?? true
            let stale = freshness == .stale || expired
            let suffix = stale ? " · Stale" + (failure.map { " · " + $0.rawValue } ?? "") : ""
            return address + suffix
        }
        return checking ? "Checking…" : failure?.rawValue ?? "Unavailable"
    }
}

enum ProxyReadState: String { case available, unavailable }
struct ProxyEndpoint: Equatable {
    let kind: String
    let scheme: String
    let host: String
    let port: Int?
    var summary: String { "\(scheme)://\(host.contains(":") ? "[\(host)]" : host)" + (port.map { ":\($0)" } ?? "") }
}
struct ProxyReading: Equatable {
    var state: ProxyReadState = .available
    var endpoints: [ProxyEndpoint] = []
    var pacURL: String? = nil
    var bypassCount = 0
    var mismatchedKeys: [String] = []
    var invalidKeys: [String] = []
    var autoDiscovery = false
    var bypassFingerprint: String? = nil
    var hasProxy: Bool { !endpoints.isEmpty || pacURL != nil || autoDiscovery }
    var summary: String {
        guard state == .available else { return "Unavailable" }
        if !invalidKeys.isEmpty { return "Invalid proxy setting" }
        let kinds = endpoints.map(\.kind) + (pacURL == nil ? [] : ["PAC"]) + (autoDiscovery ? ["Auto discovery"] : [])
        return kinds.isEmpty ? "No proxy" : kinds.joined(separator: " / ")
    }
}
struct TunnelReading: Equatable {
    var names: [String] = []
    var available = true
    var summary: String { available ? (names.isEmpty ? "None observed" : "\(names.count) tunnel-like interfaces") : "Unavailable" }
}
enum ProbeService: String, CaseIterable, Identifiable {
    case github = "GitHub", openai = "OpenAI", anthropic = "Anthropic"
    var id: Self { self }
    // HEAD requests test HTTP/TLS transport only, without inference or credentials.
    var url: URL {
        switch self {
        case .github: URL(string: "https://api.github.com/zen")!
        case .openai: URL(string: "https://api.openai.com/v1/models")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1/models")!
        }
    }
}
enum ProbeState: String { case disabled = "Probes disabled", checking = "Checking…", reachable = "Reachable", timeout = "Timeout", offline = "Offline", transportFailed = "Transport failed", unavailable = "Unavailable" }
struct ProbeReading: Equatable, Identifiable {
    let service: ProbeService
    var state: ProbeState = .checking
    var latencyMilliseconds: Double? = nil
    var httpStatus: Int? = nil
    var sampledAt: Date? = nil
    var failure: NetworkFailure? = nil
    var id: ProbeService { service }
    static func response(service: ProbeService, status: Int, latency: Double, now: Date) -> Self {
        Self(service: service, state: .reachable, latencyMilliseconds: latency,
             httpStatus: status, sampledAt: now)
    }
}
struct NetworkSnapshot: Equatable {
    var path = NetworkPathReading()
    var ipv4 = PublicIPReading(source: "ipify · api.ipify.org")
    var ipv6 = PublicIPReading(source: "ipify · api6.ipify.org")
    var environmentProxy = ProxyReading(state: .unavailable)
    var systemProxy = ProxyReading(state: .unavailable)
    var tunnel = TunnelReading(available: false)
    var probes = ProbeService.allCases.map { ProbeReading(service: $0) }
    var probesEnabled = true
    var localSampledAt: Date? = nil
    var region: String { "Not collected" }
    var proxyContext: String {
        guard environmentProxy.state == .available, systemProxy.state == .available,
              environmentProxy.invalidKeys.isEmpty, systemProxy.invalidKeys.isEmpty else { return "Unavailable" }
        let same = environmentProxy.endpoints == systemProxy.endpoints && environmentProxy.pacURL == systemProxy.pacURL && environmentProxy.autoDiscovery == systemProxy.autoDiscovery && environmentProxy.bypassFingerprint == systemProxy.bypassFingerprint && environmentProxy.mismatchedKeys.isEmpty
        return same ? "Same proxy contexts" : "Different proxy contexts"
    }
    var connectivitySummary: String {
        if !probesEnabled { return "Probes disabled" }
        if path.state == .unsatisfied || path.state == .requiresConnection { return "Offline" }
        let checking = probes.contains { $0.state == .checking }
        if checking && probes.allSatisfy({ $0.state == .checking }) { return "Checking…" }
        let reachable = probes.filter { $0.state == .reachable }.count
        return "\(reachable)/\(probes.count) reachable" + (checking ? " · Checking…" : "")
    }
}

// Monotonic deadlines are independent of the UI clock and wall-clock adjustments.
struct NetworkSchedule {
    static let ipTTL: TimeInterval = 300
    static let debounce: TimeInterval = 0.75
    static let manualCooldown: TimeInterval = 4
    static let failures: [TimeInterval] = [60, 120, 300, 600, 900]
    var ipDue: TimeInterval = 0
    var localDue: TimeInterval = 0
    var probeDue: [ProbeService: TimeInterval] = [:]
    var failureCounts: [ProbeService: Int] = [:]
    var lastManual: TimeInterval? = nil
    mutating func completedIP(at now: TimeInterval) { ipDue = now + Self.ipTTL }
    mutating func completedProbe(_ service: ProbeService, success: Bool, at now: TimeInterval) {
        let count = success ? 0 : min((failureCounts[service] ?? 0) + 1, Self.failures.count)
        failureCounts[service] = count
        probeDue[service] = now + (count == 0 ? 60 : Self.failures[count - 1])
    }
    mutating func pathChanged(at now: TimeInterval) {
        ipDue = now + Self.debounce; localDue = now + Self.debounce
        failureCounts = [:]
        probeDue = Dictionary(uniqueKeysWithValues: ProbeService.allCases.map { ($0, now + Self.debounce) })
    }
    mutating func manual(at now: TimeInterval) -> Bool {
        if let lastManual, now - lastManual < Self.manualCooldown { return false }
        lastManual = now; ipDue = now; localDue = now
        probeDue = Dictionary(uniqueKeysWithValues: ProbeService.allCases.map { ($0, now) })
        return true
    }
}
