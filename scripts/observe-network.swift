import Foundation

// Read-only smoke observation of the actual Network providers, not a unit test.
// Explicit opt-in is required; output never includes IPs, proxy URLs or bodies.
@main struct ObserveNetwork {
    @MainActor static func main() async {
        guard CommandLine.arguments.contains("--allow-external-requests") else {
            print("NOT_RUN: pass --allow-external-requests to enable ipify and unauthenticated service probes")
            return
        }
        let monitor = NetworkMonitor(onSnapshot: { _ in })
        monitor.start(probesEnabled: true)
        let deadline = ProcessInfo.processInfo.systemUptime + 12
        while ProcessInfo.processInfo.systemUptime < deadline {
            let snapshot = monitor.snapshot
            if snapshot.ipv4.attemptedAt != nil && snapshot.ipv6.attemptedAt != nil && snapshot.probes.allSatisfy({ $0.sampledAt != nil }) { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let initial = monitor.snapshot
        monitor.refresh()
        let refreshDeadline = ProcessInfo.processInfo.systemUptime + 7
        while ProcessInfo.processInfo.systemUptime < refreshDeadline {
            if monitor.snapshot.ipv4.attemptedAt != initial.ipv4.attemptedAt && monitor.snapshot.ipv6.attemptedAt != initial.ipv6.attemptedAt { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let snapshot = monitor.snapshot
        let report: [String: Any] = [
            "path": ["state": snapshot.path.state.rawValue, "interfaces": snapshot.path.interfaces.map(\.rawValue),
                     "expensive": snapshot.path.expensive as Any? ?? "UNKNOWN", "constrained": snapshot.path.constrained as Any? ?? "UNKNOWN"],
            "public_ip": ["ipv4_detected": snapshot.ipv4.address != nil, "ipv6_detected": snapshot.ipv6.address != nil,
                          "ipv4_failure": snapshot.ipv4.failure?.rawValue ?? "none", "ipv6_failure": snapshot.ipv6.failure?.rawValue ?? "none",
                          "sources": [snapshot.ipv4.source, snapshot.ipv6.source]],
            "proxy": ["app_detected": snapshot.environmentProxy.hasProxy, "system_detected": snapshot.systemProxy.hasProxy,
                      "app_state": snapshot.environmentProxy.state.rawValue, "system_state": snapshot.systemProxy.state.rawValue,
                      "context": snapshot.proxyContext],
            "tunnel": ["hint_count": snapshot.tunnel.names.count, "names": snapshot.tunnel.names, "routing": "NOT_PROVEN"],
            "connectivity": snapshot.probes.map { value -> [String: Any] in
                ["provider": value.service.rawValue, "state": value.state.rawValue,
                 "latency_ms": value.latencyMilliseconds.map { Int($0.rounded()) } as Any? ?? "UNKNOWN",
                 "http_status": value.httpStatus as Any? ?? "UNKNOWN", "auth": "NOT_TESTED"]
            },
            "manual_refresh_ipv4_updated": snapshot.ipv4.attemptedAt != initial.ipv4.attemptedAt,
            "manual_refresh_ipv6_updated": snapshot.ipv6.attemptedAt != initial.ipv6.attemptedAt,
            "monitor_starts": monitor.starts
        ]
        monitor.stop(); await monitor.waitForStop()
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print(text) }
    }
}
