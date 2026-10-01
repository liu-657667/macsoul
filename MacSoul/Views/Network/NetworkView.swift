import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    private var network: NetworkSnapshot { store.snapshot.network }
    var body: some View {
        Form {
            if store.snapshot.networkMode == .live {
                Section(language.text("Network path · LIVE")) {
                    LabeledContent(language.text("Status"), value: language.networkText(network.path.state))
                    LabeledContent(language.text("Interfaces"), value: network.path.interfaces.map { language.networkText($0) }.joined(separator: " / ").nonemptyUnavailable(language))
                    LabeledContent(language.text("Expensive network"), value: boolean(network.path.expensive))
                    LabeledContent(language.text("Low Data Mode"), value: boolean(network.path.constrained))
                }
                Section(language.text("Public exit IP")) {
                    LabeledContent("IPv4", value: network.ipv4.display(language, now: store.displayNow))
                    LabeledContent("IPv6", value: network.ipv6.display(language, now: store.displayNow))
                    Text("\(language.text("Source")) · IPv4: \(network.ipv4.source) · IPv6: \(network.ipv6.source)").font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                    LabeledContent(language.text("IPv4 updated"), value: language.sampledTime(network.ipv4.sampledAt))
                    LabeledContent(language.text("IPv6 updated"), value: language.sampledTime(network.ipv6.sampledAt))
                    LabeledContent(language.text("Region"), value: language.text(network.region))
                    Text(language.text("Public IP requests go to ipify; this is the provider-observed exit, not a device location."))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                }
                Section(language.text("Proxy")) {
                    proxyDetails("App environment proxy", reading: network.environmentProxy)
                    Divider()
                    proxyDetails("macOS system proxy", reading: network.systemProxy, system: true)
                    LabeledContent(language.text("Context"), value: language.text(network.proxyContext))
                    Text(language.text("App environment is MacSoul's process environment, not the current Terminal shell. Uppercase keys take precedence; differences are reported."))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                }
                Section(language.text("Tunnel hints")) {
                    Text(network.tunnel.display(language))
                    if !network.tunnel.names.isEmpty { Text(network.tunnel.names.joined(separator: ", ")).font(.system(.body, design: .monospaced)) }
                    Text(language.text("Tunnel interfaces are hints, not proof of VPN routing."))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                }
                Section(language.text("Connectivity")) {
                    ForEach(network.probes) { probe in
                        LabeledContent(probe.service.displayName) {
                            HStack(spacing: 8) {
                                Text(language.networkText(probe.state))
                                if let ms = probe.latencyMilliseconds { Text("\(Int(ms.rounded())) ms").monospacedDigit() }
                                if let code = probe.httpStatus { Text("HTTP \(String(code))").foregroundStyle(MacSoulTheme.supportingText) }
                            }
                        }
                        Text(probe.service.url.absoluteString).font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                        if let sampled = probe.sampledAt {
                            Text("\(language.networkLabel("Updated")) · \(language.dateTime(sampled))")
                                .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                        }
                    }
                    Text(language.text("HTTP/TLS transport only. Authentication not tested; an HTTP response does not prove full service health."))
                        .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                    Button(language.text("Refresh network")) { store.refreshNetwork() }
                    Text(language.text("Refresh updates IP, proxy, tunnel and probes; it does not restart path or System/Dev monitoring."))
                        .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                }
            } else {
                Section(language.text("Network · MOCK DATA")) {
                    LabeledContent(language.text("Public IP"), value: language.text(store.snapshot.publicIP ?? "Unavailable"))
                    LabeledContent(language.text("Region"), value: language.text(store.snapshot.region ?? "Unavailable"))
                    LabeledContent(language.text("Proxy hint"), value: language.text(store.snapshot.proxyHint))
                    LabeledContent(language.text("Tunnel hint"), value: language.text(store.snapshot.tunnelHint))
                }
                Text(language.text("No external probe is connected.")).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).navigationTitle(language.text("Network"))
    }
    private func boolean(_ value: Bool?) -> String { language.text(value.map { $0 ? "Yes" : "No" } ?? "Unavailable") }
    @ViewBuilder private func proxyDetails(_ title: String, reading: ProxyReading, system: Bool = false) -> some View {
        Text(language.text(title)).font(.headline)
        Text(reading.display(language, system: system))
        ForEach(reading.endpoints.indices, id: \.self) { index in
            LabeledContent(reading.endpoints[index].kind, value: reading.endpoints[index].summary)
        }
        if let pac = reading.pacURL { LabeledContent("PAC", value: pac) }
        if reading.bypassCount > 0 { Text(language == .english ? "\(reading.bypassCount) bypass entries" : "\(reading.bypassCount) 个绕过条目").font(.caption) }
        if !reading.mismatchedKeys.isEmpty {
            Text(language.text("Upper/lowercase proxy mismatch") + ": " + reading.mismatchedKeys.joined(separator: ", ")).font(.caption)
        }
        if !reading.invalidKeys.isEmpty {
            Text(language.text("Invalid proxy setting") + ": " + reading.invalidKeys.joined(separator: ", ")).font(.caption)
        }
    }
}

// Both summaries read the same structured snapshot; no provider work in Views.
struct NetworkSummary: View {
    let snapshot: NetworkSnapshot
    let now: Date
    var compact = false
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 10) {
            LabeledContent(compact ? language.text("IP") : language.text("Public IPv4"), value: snapshot.ipv4.display(language, now: now))
            if !compact {
                LabeledContent(language.text("Network path"), value: (snapshot.path.interfaces.map { language.networkText($0) } + [language.networkText(snapshot.path.state)]).joined(separator: " · "))
            }
            LabeledContent(compact ? language.text("Proxy") : language.text("System proxy"), value: snapshot.systemProxy.display(language, system: true))
            LabeledContent(language.text("Tunnel hint"), value: snapshot.tunnel.display(language))
            if !compact {
                LabeledContent(language.text("Connectivity"), value: snapshot.connectivityDisplay(language))
            }
        }
    }
}
extension PublicIPReading {
    func display(_ language: MacSoulLanguage, now: Date) -> String {
        if let address {
            let expired = sampledAt.map { now.timeIntervalSince($0) >= NetworkSchedule.ipTTL } ?? true
            guard freshness == .stale || expired else { return address }
            return ([address, language.text("Stale")] + (failure.map { [language.networkText($0)] } ?? []))
                .joined(separator: " · ")
        }
        if checking { return language.text("Checking…") }
        return failure.map { language.networkText($0) } ?? language.text("Unavailable")
    }
}
extension ProxyReading {
    func display(_ language: MacSoulLanguage, system: Bool = false) -> String {
        guard state == .available else { return language.text("Unavailable") }
        if !invalidKeys.isEmpty { return language.text("Invalid proxy setting") }
        let kinds = endpoints.map(\.kind) + (pacURL == nil ? [] : ["PAC"])
            + (autoDiscovery ? [language.text("Auto discovery")] : [])
        return kinds.isEmpty ? language.text(system ? "No system proxy" : "No proxy") : kinds.joined(separator: " / ")
    }
}
extension ProbeService {
    var displayName: String {
        switch self {
        case .github: "GitHub"
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }
}
extension MacSoulLanguage {
    // Network timestamps use a noun label; other sections retain their existing Updated copy.
    func networkLabel(_ key: String) -> String {
        if key == "Updated", self == .chinese { return "更新时间" }
        return text(key)
    }
    func networkText(_ state: NetworkPathState) -> String {
        switch state {
        case .sampling: text("Monitoring…")
        case .satisfied: text("Connected")
        case .requiresConnection: text("Connection required")
        case .unsatisfied: text("Offline")
        case .unavailable: text("Unavailable")
        }
    }
    func networkText(_ interface: NetworkInterfaceKind) -> String {
        switch interface {
        case .wifi: "Wi-Fi"
        case .ethernet: text("Ethernet")
        case .cellular: text("Cellular")
        case .loopback: text("Loopback")
        case .other: text("Other")
        }
    }
    func networkText(_ failure: NetworkFailure) -> String {
        switch failure {
        case .timeout: text("Timeout")
        case .transport: text("Transport failed")
        case .http: text("HTTP failed")
        case .malformed: text("Invalid response")
        case .tooLarge: text("Response too large")
        case .unavailable: text("Unavailable")
        case .offline: text("Offline")
        }
    }
    func networkText(_ state: ProbeState) -> String {
        switch state {
        case .disabled: text("Probes disabled")
        case .checking: text("Checking…")
        case .reachable: text("Reachable")
        case .timeout: text("Timeout")
        case .offline: text("Offline")
        case .transportFailed: text("Transport failed")
        case .unavailable: text("Unavailable")
        }
    }
}
extension TunnelReading {
    func display(_ language: MacSoulLanguage) -> String {
        if available && !names.isEmpty { return language == .english ? summary : "\(names.count) 个类隧道接口" }
        if available && names.isEmpty { return language.text("No tunnel hints") }
        return language.text(summary)
    }
}
private extension String {
    func nonemptyUnavailable(_ language: MacSoulLanguage) -> String { isEmpty ? language.text("Unavailable") : self }
}

// Presentation only: mirrors the existing summary states without changing the snapshot.
extension NetworkSnapshot {
    func connectivityDisplay(_ language: MacSoulLanguage) -> String {
        if !probesEnabled { return language.text("Probes disabled") }
        if path.state == .unsatisfied || path.state == .requiresConnection { return language.text("Offline") }
        let count = probes.filter { $0.state == .reachable }.count
        return language == .english ? "\(count)/\(probes.count) reachable" : "\(count)/\(probes.count) 可达"
    }
}
