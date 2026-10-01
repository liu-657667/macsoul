import Foundation
import Network
import CFNetwork
import CryptoKit
import Darwin

@MainActor protocol NetworkPathProviding: AnyObject {
    func start(_ receive: @escaping @MainActor (NetworkPathReading) -> Void)
    func stop()
}

@MainActor final class NativeNetworkPathProvider: NetworkPathProviding {
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "local.macsoul.network-path", qos: .utility)
    private var generation = 0
    private(set) var starts = 0
    func start(_ receive: @escaping @MainActor (NetworkPathReading) -> Void) {
        guard monitor == nil else { return }
        generation += 1; starts += 1
        let token = generation
        let active = NWPathMonitor()
        monitor = active
        active.pathUpdateHandler = { [weak self] path in
            let reading = Self.reading(path)
            Task { @MainActor in
                guard let self, self.monitor != nil, self.generation == token else { return }
                receive(reading)
            }
        }
        active.start(queue: queue)
    }
    func stop() {
        generation += 1
        monitor?.cancel(); monitor = nil
    }
    deinit { monitor?.cancel() }
    nonisolated static func reading(_ path: NWPath) -> NetworkPathReading {
        let state: NetworkPathState
        switch path.status {
        case .satisfied: state = .satisfied
        case .requiresConnection: state = .requiresConnection
        case .unsatisfied: state = .unsatisfied
        @unknown default: state = .unavailable
        }
        let types: [(NWInterface.InterfaceType, NetworkInterfaceKind)] = [
            (.wifi, .wifi), (.wiredEthernet, .ethernet), (.cellular, .cellular), (.loopback, .loopback), (.other, .other)]
        return NetworkPathReading(state: state,
            interfaces: types.filter { path.usesInterfaceType($0.0) }.map(\.1),
            interfaceNames: path.availableInterfaces.filter { path.usesInterfaceType($0.type) }.map(\.name).sorted(),
            expensive: path.isExpensive, constrained: path.isConstrained,
            supportsIPv4: path.supportsIPv4, supportsIPv6: path.supportsIPv6)
    }
}

struct NetworkHTTPResponse { let status: Int; let body: Data }
protocol NetworkHTTPClient: Sendable {
    func request(url: URL, method: String, maxBytes: Int) async throws -> NetworkHTTPResponse
}

// One short-lived, nonpersistent session per bounded request. Cancellation also
// cancels the underlying task; redirects cannot silently select another host.
struct EphemeralNetworkHTTPClient: NetworkHTTPClient {
    static func configuration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil; config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil; config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 4; config.timeoutIntervalForResource = 5
        return config
    }
    func request(url: URL, method: String, maxBytes: Int) async throws -> NetworkHTTPResponse {
        let session = URLSession(configuration: Self.configuration(), delegate: NoNetworkRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        return try await withTaskCancellationHandler {
            var request = URLRequest(url: url, timeoutInterval: 4)
            request.httpMethod = method
            request.httpShouldHandleCookies = false
            // No user headers, credentials, environment, project data or request body.
            let (bytes, response) = try await session.bytes(for: request)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else { throw NetworkFailure.transport }
            if method == "HEAD" { return NetworkHTTPResponse(status: response.statusCode, body: Data()) }
            guard response.expectedContentLength <= Int64(maxBytes) else { throw NetworkFailure.tooLarge }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < maxBytes else { throw NetworkFailure.tooLarge }
                data.append(byte)
            }
            return NetworkHTTPResponse(status: response.statusCode, body: data)
        } onCancel: {
            session.invalidateAndCancel()
        }
    }
}
private final class NoNetworkRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct PublicIPProvider: Sendable {
    let client: any NetworkHTTPClient
    init(client: any NetworkHTTPClient = EphemeralNetworkHTTPClient()) { self.client = client }
    static func endpoint(_ family: IPFamily) -> URL {
        URL(string: family == .ipv4 ? "https://api.ipify.org" : "https://api6.ipify.org")!
    }
    static func parse(_ data: Data, family: IPFamily) throws -> String {
        guard data.count <= 1024 else { throw NetworkFailure.tooLarge }
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, !text.contains("%") else { throw NetworkFailure.malformed }
        if family == .ipv4 {
            let octets = text.split(separator: ".", omittingEmptySubsequences: false)
            guard octets.count == 4, octets.allSatisfy({ octet in
                !octet.isEmpty && octet.utf8.allSatisfy { (48...57).contains($0) }
                    && (octet.count == 1 || octet.first != "0")
                    && Int(octet).map { (0...255).contains($0) } == true
            }) else { throw NetworkFailure.malformed }
        }
        var v4 = in_addr(), v6 = in6_addr()
        let valid = text.withCString { pointer in
            family == .ipv4 ? inet_pton(AF_INET, pointer, &v4) : inet_pton(AF_INET6, pointer, &v6)
        }
        guard valid == 1 else { throw NetworkFailure.malformed }
        return text
    }
    func fetch(_ family: IPFamily) async throws -> String {
        let response = try await client.request(url: Self.endpoint(family), method: "GET", maxBytes: 1024)
        guard (200...299).contains(response.status) else { throw NetworkFailure.http }
        return try Self.parse(response.body, family: family)
    }
}
func networkFailure(_ error: Error) -> NetworkFailure {
    if let failure = error as? NetworkFailure { return failure }
    if let urlError = error as? URLError {
        if urlError.code == .timedOut { return .timeout }
        if urlError.code == .notConnectedToInternet { return .offline }
    }
    return .transport // Never publish error descriptions containing a URL or payload.
}

struct ConnectivityProvider: Sendable {
    let client: any NetworkHTTPClient
    func probe(_ service: ProbeService, now: @Sendable () -> Date = { Date() },
               uptime: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) async throws -> ProbeReading {
        let start = uptime()
        let response = try await client.request(url: service.url, method: "HEAD", maxBytes: 0)
        // Every HTTP status proves a response, including unauthenticated 401/403.
        return .response(service: service, status: response.status,
                         latency: max(0, uptime() - start) * 1000, now: now())
    }
}

struct ProxyParser {
    // Retain only scheme, host and port. Userinfo/path/query/fragment never enter a snapshot.
    static func endpoint(_ text: String, kind: String) -> ProxyEndpoint? {
        guard !text.isEmpty, !text.contains(where: { $0.isWhitespace || $0.isNewline }),
              let parts = URLComponents(string: text),
              let scheme = parts.scheme?.lowercased(), ["http", "https", "socks", "socks5", "socks5h", "socks4"].contains(scheme),
              let rawHost = parts.host, !rawHost.isEmpty,
              parts.port.map({ (1...65535).contains($0) }) ?? true else { return nil }
        let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        guard !host.contains("@"), !host.contains("/"), !host.contains("%") else { return nil }
        return ProxyEndpoint(kind: kind, scheme: scheme, host: host, port: parts.port)
    }
    static func environment(_ environment: [String: String]) -> ProxyReading {
        var result = ProxyReading()
        for (key, kind) in [("HTTP_PROXY", "HTTP"), ("HTTPS_PROXY", "HTTPS"), ("ALL_PROXY", "ALL")] {
            let upper = environment[key], lower = environment[key.lowercased()]
            if let upper, let lower, upper != lower { result.mismatchedKeys.append(key) }
            // Uppercase wins, explicitly reported when the contexts disagree.
            guard let value = upper ?? lower, !value.isEmpty else { continue }
            if let endpoint = endpoint(value, kind: kind) { result.endpoints.append(endpoint) }
            else { result.invalidKeys.append(key) }
        }
        if let upper = environment["NO_PROXY"], let lower = environment["no_proxy"], upper != lower {
            result.mismatchedKeys.append("NO_PROXY")
        }
        let bypass = (environment["NO_PROXY"] ?? environment["no_proxy"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        result.bypassCount = bypass.count
        result.bypassFingerprint = bypassFingerprint(bypass)
        return result
    }
    private static func bypassFingerprint(_ entries: [String]) -> String? {
        guard !entries.isEmpty else { return nil }
        let canonical = entries.map { $0.lowercased() }.sorted().joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func system(_ values: [String: Any]?) -> ProxyReading {
        guard let values else { return ProxyReading(state: .unavailable) }
        var result = ProxyReading()
        for (prefix, kind, scheme) in [("HTTP", "HTTP", "http"), ("HTTPS", "HTTPS", "http"), ("SOCKS", "SOCKS", "socks5")] {
            guard (values[prefix + "Enable"] as? NSNumber)?.boolValue == true else { continue }
            guard let host = values[prefix + "Proxy"] as? String,
                  let port = (values[prefix + "Port"] as? NSNumber)?.intValue,
                  let endpoint = endpoint("\(scheme)://\(host.contains(":") ? "[\(host)]" : host):\(port)", kind: kind) else {
                result.invalidKeys.append(prefix); continue
            }
            result.endpoints.append(endpoint)
        }
        if (values["ProxyAutoConfigEnable"] as? NSNumber)?.boolValue == true {
            if let url = values["ProxyAutoConfigURLString"] as? String, let endpoint = endpoint(url, kind: "PAC") {
                result.pacURL = endpoint.summary
            } else { result.invalidKeys.append("PAC") }
        }
        result.autoDiscovery = (values["ProxyAutoDiscoveryEnable"] as? NSNumber)?.boolValue == true
        let bypass = values["ExceptionsList"] as? [String] ?? []
        result.bypassCount = bypass.count
        result.bypassFingerprint = bypassFingerprint(bypass)
        return result
    }
}
struct LocalNetworkReading { let environment: ProxyReading; let system: ProxyReading; let tunnel: TunnelReading }
protocol LocalNetworkProviding: Sendable { func read() async -> LocalNetworkReading }
actor NativeLocalNetworkProvider: LocalNetworkProviding {
    func read() -> LocalNetworkReading {
        let system = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
        var list: UnsafeMutablePointer<ifaddrs>?
        let success = getifaddrs(&list) == 0
        var names: [String] = []
        if success {
            var cursor = list
            while let entry = cursor {
                if entry.pointee.ifa_flags & UInt32(IFF_UP) != 0 {
                    names.append(String(cString: entry.pointee.ifa_name))
                }
                cursor = entry.pointee.ifa_next
            }
            freeifaddrs(list)
        }
        return LocalNetworkReading(environment: ProxyParser.environment(ProcessInfo.processInfo.environment),
                                   system: ProxyParser.system(system),
                                   tunnel: TunnelReading(names: Self.tunnelHints(names), available: success))
    }
    nonisolated static func tunnelHints(_ names: [String]) -> [String] {
        Array(Set(names.filter { name in ["utun", "tun", "tap", "ppp", "ipsec"].contains { name.hasPrefix($0) } })).sorted()
    }
}
