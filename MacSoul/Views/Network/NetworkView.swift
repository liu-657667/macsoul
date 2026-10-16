import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    private var network: NetworkSnapshot { store.snapshot.network }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                if store.snapshot.networkMode == .live {
                    TypographySection(language.text("Network path · LIVE")) {
                        Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card, verticalSpacing: MacSoulTheme.Spacing.regular) {
                            networkField(language.text("Status"), value: language.networkText(network.path.state))
                            networkField(language.text("Interfaces"), value: network.path.interfaces.map { language.networkText($0) }.joined(separator: " / ").nonemptyUnavailable(language))
                            networkField(language.text("Expensive network"), value: boolean(network.path.expensive))
                            networkField(language.text("Low Data Mode"), value: boolean(network.path.constrained))
                        }
                    }
                    TypographySection(language.text("Public exit IP")) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                            publicIPDetails("IPv4", reading: network.ipv4)
                            Divider()
                            publicIPDetails("IPv6", reading: network.ipv6)
                            Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card) {
                                networkField(language.text("Region"), value: language.text(network.region))
                            }
                            Text(language.text("Primary: IPinfo · Fallback: ident.me. Each service can observe the request's public exit IP; no device location is collected."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        }
                    }
                    TypographySection(language.text("Proxy")) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                            proxyDetails("App environment proxy", reading: network.environmentProxy)
                            Divider()
                            proxyDetails("macOS system proxy", reading: network.systemProxy, system: true)
                            Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card) {
                                networkField(language.text("Context"), value: language.text(network.proxyContext))
                            }
                            Text(language.text("App environment is MacSoul's process environment, not the current Terminal shell. Uppercase keys take precedence; differences are reported."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        }
                    }
                    TypographySection(language.text("Tunnel hints")) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                            Text(network.tunnel.display(language)).font(MacSoulTheme.Typography.fieldValue)
                            if !network.tunnel.names.isEmpty {
                                Text(network.tunnel.names.joined(separator: ", "))
                                    .font(MacSoulTheme.Typography.technical).fixedSize(horizontal: false, vertical: true)
                            }
                            Text(language.text("Tunnel interfaces are hints, not proof of VPN routing."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        }
                    }
                    TypographySection(language.text("Connectivity")) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                            ForEach(network.probes) { probe in
                                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                                    Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card) {
                                        networkField(probe.service.displayName, value: language.networkText(probe.state))
                                    }
                                    HStack(spacing: MacSoulTheme.Spacing.tight) {
                                        if let ms = probe.latencyMilliseconds {
                                            Text("\(Int(ms.rounded())) ms").monospacedDigit()
                                        }
                                        if let code = probe.httpStatus { Text("HTTP \(String(code))") }
                                    }.font(MacSoulTheme.Typography.supporting)
                                    Text(probe.service.url.absoluteString)
                                        .font(MacSoulTheme.Typography.technical).fixedSize(horizontal: false, vertical: true)
                                    if let sampled = probe.sampledAt {
                                        Text("\(language.networkLabel("Updated")) · \(language.dateTime(sampled))")
                                            .font(MacSoulTheme.Typography.supporting)
                                    }
                                }
                            }
                            Text(language.text("HTTP/TLS transport only. Authentication not tested; an HTTP response does not prove full service health."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                            Button(language.text("Refresh network")) { store.refreshNetwork() }
                            Text(language.text("Refresh updates IP, proxy, tunnel and probes; it does not restart path or System/Dev monitoring."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        }
                    }
                } else {
                    TypographySection(language.text("Network · MOCK DATA")) {
                        Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card, verticalSpacing: MacSoulTheme.Spacing.regular) {
                            networkField(language.text("Public IP"), value: language.text(store.snapshot.publicIP ?? "Unavailable"), font: MacSoulTheme.Typography.technical)
                            networkField(language.text("Region"), value: language.text(store.snapshot.region ?? "Unavailable"))
                            networkField(language.text("Proxy hint"), value: language.text(store.snapshot.proxyHint))
                            networkField(language.text("Tunnel hint"), value: language.text(store.snapshot.tunnelHint))
                        }
                    }
                    Text(language.text("No external probe is connected.")).font(MacSoulTheme.Typography.supporting)
                }
            }
            .frame(maxWidth: 900, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(MacSoulTheme.Spacing.section)
        }.navigationTitle(language.text("Network"))
    }
    private func boolean(_ value: Bool?) -> String { language.text(value.map { $0 ? "Yes" : "No" } ?? "Unavailable") }

    private func networkField(_ label: String, value: String, font: Font = MacSoulTheme.Typography.fieldValue) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label).font(MacSoulTheme.Typography.fieldLabel)
                .frame(maxWidth: 180, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            Text(value).font(font).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityValue(value)
    }

    private func publicIPDetails(_ family: String, reading: PublicIPReading) -> some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            Text(family).font(MacSoulTheme.Typography.itemTitle).accessibilityAddTraits(.isHeader)
            Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card, verticalSpacing: MacSoulTheme.Spacing.tight) {
                networkField(language.text("Public IP"), value: reading.display(language, now: store.displayNow), font: MacSoulTheme.Typography.technical)
                networkField(language.text("Status"), value: reading.statusDisplay(language, now: store.displayNow), font: MacSoulTheme.Typography.status)
                networkField(language.text("Last successful source"), value: reading.sourceDisplay(language))
                networkField(language.text("Last successful lookup"), value: language.sampledTime(reading.sampledAt), font: MacSoulTheme.Typography.supporting)
                networkField(language.text("Last lookup attempt"), value: language.sampledTime(reading.attemptedAt), font: MacSoulTheme.Typography.supporting)
                if let failure = reading.failure {
                    networkField(language.text("Latest failure"), value: language.networkText(failure))
                    if let failedAt = reading.failedAt {
                        networkField(language.text("Last failed lookup"), value: language.sampledTime(failedAt), font: MacSoulTheme.Typography.supporting)
                    }
                }
            }
            .textSelection(.enabled)
        }
    }

    private func proxyDetails(_ title: String, reading: ProxyReading, system: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            Text(language.text(title)).font(MacSoulTheme.Typography.itemTitle).accessibilityAddTraits(.isHeader)
            Text(reading.display(language, system: system)).font(MacSoulTheme.Typography.status)
            Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card, verticalSpacing: MacSoulTheme.Spacing.tight) {
                ForEach(reading.endpoints.indices, id: \.self) { index in
                    networkField(reading.endpoints[index].kind, value: reading.endpoints[index].summary, font: MacSoulTheme.Typography.technical)
                }
                if let pac = reading.pacURL { networkField("PAC", value: pac, font: MacSoulTheme.Typography.technical) }
            }
            if reading.bypassCount > 0 {
                Text(language == .english ? "\(reading.bypassCount) bypass entries" : "\(reading.bypassCount) 个绕过条目")
                    .font(MacSoulTheme.Typography.supporting)
            }
            if !reading.mismatchedKeys.isEmpty {
                Text(language.text("Upper/lowercase proxy mismatch") + ": " + reading.mismatchedKeys.joined(separator: ", "))
                    .font(MacSoulTheme.Typography.status).fixedSize(horizontal: false, vertical: true)
            }
            if !reading.invalidKeys.isEmpty {
                Text(language.text("Invalid proxy setting") + ": " + reading.invalidKeys.joined(separator: ", "))
                    .font(MacSoulTheme.Typography.status).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// Both summaries read the same structured snapshot; no provider work in Views.
struct NetworkSummary: View {
    let snapshot: NetworkSnapshot
    let now: Date
    var compact = false
    var surface: SummarySurface = .standard
    @Environment(\.macSoulLanguage) private var language
    @ViewBuilder var body: some View {
        if surface == .standard { standardContent } else { summaryContent }
    }
    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            LabeledContent(compact ? language.text("IP") : language.text("Public IPv4"), value: Self.addressLabel(snapshot.ipv4, now: now, language: language, surface: surface))
                .labeledContentStyle(SummaryLabeledContentStyle(technicalValue: true))
            if !compact {
                LabeledContent(language.text("Network path"), value: (snapshot.path.interfaces.map { language.networkText($0) } + [language.networkText(snapshot.path.state)]).joined(separator: " · "))
            }
            LabeledContent(compact ? language.text("Proxy") : language.text("System proxy"), value: snapshot.systemProxy.display(language, system: true))
            LabeledContent(language.text("Tunnel hint"), value: snapshot.tunnel.display(language))
            if !compact {
                LabeledContent(language.text("Connectivity"), value: snapshot.connectivityDisplay(language))
            }
        }.labeledContentStyle(SummaryLabeledContentStyle())
    }
    private var standardContent: some View {
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
    static func addressLabel(_ reading: PublicIPReading, now: Date, language: MacSoulLanguage,
                             surface: SummarySurface = .standard) -> String {
        // Only the opt-in summary collapses two identical unavailable dimensions.
        // Historical addresses, Querying and specific failure reasons retain display().
        if surface != .standard, reading.address == nil, !reading.checking, reading.failure == .unavailable {
            return language.text("Unavailable")
        }
        return reading.display(language, now: now)
    }

}
extension PublicIPReading {
    func statusDisplay(_ language: MacSoulLanguage, now: Date) -> String {
        let expired = sampledAt.map { now.timeIntervalSince($0) >= NetworkSchedule.ipTTL } ?? true
        let status = address == nil ? "Unavailable" : freshness == .stale || expired ? "Stale" : "Fresh"
        return (checking ? language.text("Querying…") + " · " : "") + language.text(status)
    }
    func sourceDisplay(_ language: MacSoulLanguage) -> String {
        guard address != nil, sampledAt != nil, let source else { return language.text("Not sampled") }
        return source.displayName
    }
    func display(_ language: MacSoulLanguage, now: Date) -> String {
        if let address {
            let expired = sampledAt.map { now.timeIntervalSince($0) >= NetworkSchedule.ipTTL } ?? true
            guard freshness == .stale || expired else { return address }
            return ([address, language.text("Stale")] + (failure.map { [language.networkText($0)] } ?? []))
                .joined(separator: " · ")
        }
        if checking { return language.text("Querying…") }
        return language.text("Unavailable") + (failure.map { " · " + language.networkText($0) } ?? "")
    }
}
extension PublicIPSource {
    var displayName: String { self == .ipinfo ? "IPinfo" : "ident.me" }
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
        case .tls: text("TLS validation failed")
        case .unsupported: text("Not supported by this network")
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
        if language == .english { return connectivitySummary }
        if !probesEnabled { return language.text("Probes disabled") }
        if path.state == .unsatisfied || path.state == .requiresConnection { return language.text("Offline") }
        let checking = probes.contains { $0.state == .checking }
        if checking && probes.allSatisfy({ $0.state == .checking }) { return language.text("Checking…") }
        let count = probes.filter { $0.state == .reachable }.count
        return "\(count)/\(probes.count) 可达" + (checking ? " · 正在探测" : "")
    }
}
