import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language

    private let metricColumns = [
        GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card),
        GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, MacSoulTheme.Spacing.card)
                .padding(.vertical, MacSoulTheme.Spacing.regular)
            Divider()
            ScrollView {
                HStack(alignment: .top, spacing: MacSoulTheme.Spacing.card) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.card) {
                        soulCard
                        aiCard
                        devCard
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.card) {
                        systemCard
                        networkCard
                        cleanerCard
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(MacSoulTheme.Spacing.card)
            }
        }
        .navigationTitle(language.text("Overview"))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.regular) {
            Text("MacSoul").font(.title2.bold())
            Text(language.text(store.systemMode == .live
                ? "SYSTEM + DEV + NETWORK LIVE · AI MOCK"
                : "MOCK DATA · No live sampling or quota provider"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var soulCard: some View {
        CardContainer(title: "Soul", assetImage: "MacSoulMenuTemplateDraft") {
            HStack(spacing: MacSoulTheme.Spacing.card) {
                SoulArtwork(visual: store.snapshot.soulVisual, size: MacSoulTheme.Size.soulArtwork)
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(store.snapshot.soulMood))
                        .font(.title3.bold())
                    Text(language.text(store.snapshot.soulMessage))
                        .foregroundStyle(MacSoulTheme.supportingText)
                }
            }
        }
    }

    private var systemCard: some View {
        CardContainer(title: "System", systemImage: "gauge.with.dots.needle.50percent") {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                LazyVGrid(columns: metricColumns, spacing: MacSoulTheme.Spacing.regular) {
                    MetricTile(name: "CPU", metric: store.snapshot.cpu, compact: true)
                    MetricTile(name: "Memory used", metric: store.snapshot.memoryUsed, compact: true)
                    MetricTile(name: "Disk", metric: store.snapshot.disk, compact: true,
                               emptyStateText: store.snapshot.diskEmptyState)
                    MetricTile(name: "Battery", metric: store.snapshot.battery, compact: true,
                               attentionText: store.snapshot.battery.usedPercent.map { $0 <= 10 ? "Low battery" : nil } ?? nil,
                               overrideLabel: store.snapshot.batterySummaryOverride,
                               emptyStateText: store.snapshot.batteryEmptyState)
                }
                MemoryPressureLabel(pressure: store.snapshot.memoryPressure)
                if store.systemMode == .live {
                    Text(language.text("System, Dev and Network: Live · AI: Mock"))
                        .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                }
            }
        }
    }

    private var aiCard: some View {
        CardContainer(title: "AI Coding", systemImage: "sparkles", badge: "MOCK") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.snapshot.quotas) { quota in
                    QuotaRow(quota: quota, presentation: .summary)
                    if quota.id != store.snapshot.quotas.last?.id { Divider() }
                }
            }
        }
    }

    private var networkCard: some View {
        CardContainer(title: "Network", systemImage: "network", badge: store.snapshot.networkMode == .live ? "LIVE" : "MOCK") {
            if store.snapshot.networkMode == .live {
                NetworkSummary(snapshot: store.snapshot.network, now: store.displayNow)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent(language.text("Public IP"), value: language.text(store.snapshot.publicIP ?? "Unavailable"))
                    LabeledContent(language.text("Region"), value: language.text(store.snapshot.region ?? "Unavailable"))
                    LabeledContent(language.text("Proxy"), value: language.text(store.snapshot.proxyHint))
                    LabeledContent(language.text("Tunnel hint"), value: language.text(store.snapshot.tunnelHint))
                    Divider()
                    ForEach(store.snapshot.serviceLatency, id: \.0) { item in
                        LabeledContent(language.text(item.0), value: language.text(item.1))
                    }
                }
            }
        }
    }

    private var devCard: some View {
        CardContainer(title: "Dev Environment", systemImage: "terminal",
                      badge: store.snapshot.devMode == .live ? "LIVE" : "MOCK") {
            VStack(alignment: .leading, spacing: 12) {
                if store.snapshot.devMode == .live, let reading = store.snapshot.runtimeReading {
                    if reading.state == .sampling {
                        Text(language.text("Sampling…"))
                    } else {
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                            ForEach(reading.records) { runtime in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(runtime.name).foregroundStyle(.secondary)
                                    Text(language.text(runtime.primary?.version ?? runtime.status.label)).fontWeight(.semibold)
                                    Text(runtime.primary?.source ?? language.text("Current detection context"))
                                        .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
                                        .help(runtime.primary?.path ?? "")
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ForEach(store.snapshot.runtimes) { runtime in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(runtime.name).foregroundStyle(.secondary)
                                Text(language.text(runtime.version)).fontWeight(.semibold)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Divider()
                Text(language.text(store.snapshot.devMode == .live
                    ? "Developer TCP Listeners" : "Listening Ports"))
                    .foregroundStyle(.secondary)
                if store.snapshot.devMode == .live, let reading = store.snapshot.portReading {
                    if reading.state == .available || reading.state == .empty {
                        if reading.developerListeners.isEmpty {
                            Text(language.text("No developer TCP listeners found"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(reading.overviewListeners) { item in
                            Text(item.overviewSummary)
                                .font(.caption.monospaced()).lineLimit(1)
                        }
                        if reading.developerListeners.count > 3 {
                            Text(language.text("More in Dev"))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(language.text(reading.state.label)).font(.caption).foregroundStyle(.secondary)
                    }
                } else { FlowPortsView(ports: store.snapshot.ports) }
            }
        }
    }

    private var cleanerCard: some View {
        CardContainer(title: "Cleaner", assetImage: "CleanerBroom") {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.cleanerText("Read only")).foregroundStyle(.secondary)
                if store.snapshot.cleaner.mode == .live {
                    Text(language.cleanerSummary(store.snapshot.cleaner)).font(.headline)
                } else {
                    Text(language.text("MOCK") + " · " + language.cleanerText("Not scanned"))
                }
                ForEach(store.snapshot.cleaner.mode == .mock ? store.snapshot.cleanerItems : []) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text(language.cleanerText(item.risk == .safe ? "Low risk" : item.risk == .caution ? "Caution" : "High risk"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(item.size)
                            .frame(width: 72, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct FlowPortsView: View {
    @Environment(\.macSoulLanguage) private var language
    let ports: [PortItem]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ports) { item in
                Text("\(item.displayPort) · \(language.text(item.process))")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }
}
