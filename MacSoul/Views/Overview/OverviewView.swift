import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language

    // Pure display override for synthetic review; nil uses the real store mode.
    var presentationMode: SystemMode? = nil

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
        // Let the native split view shrink the detail column at low window
        // heights; the card list scrolls instead of imposing an ideal height.
        .frame(minHeight: 0, maxHeight: .infinity)
        .navigationTitle(language.text("Overview"))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.regular) {
            Text("MacSoul").font(MacSoulTheme.Typography.brandTitle)
            SummaryModeLabel(mode: presentationMode ?? store.systemMode)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var soulCard: some View {
        CardContainer(title: "Soul", assetImage: "MacSoulMenuTemplateDraft", surface: .overview) {
            HStack(spacing: MacSoulTheme.Spacing.card) {
                SoulArtwork(visual: store.snapshot.soulVisual, size: MacSoulTheme.Size.soulArtwork, surface: .overview)
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(store.snapshot.soulMood))
                        .font(MacSoulTheme.Typography.itemTitle)
                    Text(language.text(store.snapshot.soulMessage))
                        .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var systemCard: some View {
        CardContainer(title: "System", systemImage: "gauge.with.dots.needle.50percent", surface: .overview) {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                LazyVGrid(columns: metricColumns, spacing: MacSoulTheme.Spacing.regular) {
                    MetricTile(name: "CPU", metric: store.snapshot.cpu, compact: true, surface: .overview)
                    MetricTile(name: "Memory used", metric: store.snapshot.memoryUsed, compact: true, surface: .overview)
                    MetricTile(name: "Disk", metric: store.snapshot.disk, compact: true,
                               emptyStateText: store.snapshot.diskEmptyState, surface: .overview)
                    MetricTile(name: "Battery", metric: store.snapshot.battery, compact: true,
                               attentionText: store.snapshot.battery.usedPercent.map { $0 <= 10 ? "Low battery" : nil } ?? nil,
                               overrideLabel: store.snapshot.batterySummaryOverride,
                               emptyStateText: store.snapshot.batteryEmptyState, surface: .overview)
                }
                MemoryPressureLabel(pressure: store.snapshot.memoryPressure, surface: .overview)
            }
        }
    }

    private var aiCard: some View {
        CardContainer(title: "AI Coding", systemImage: "sparkles", badge: store.snapshot.quotaMode.rawValue, surface: .overview) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.snapshot.quotas) { quota in
                    QuotaRow(quota: quota, presentation: .summary, appearance: .overviewSummary)
                    if quota.id != store.snapshot.quotas.last?.id { Divider() }
                }
            }
        }
    }

    private var networkCard: some View {
        CardContainer(title: "Network", systemImage: "network", badge: store.snapshot.networkMode == .live ? "LIVE" : "MOCK", surface: .overview) {
            if store.snapshot.networkMode == .live {
                NetworkSummary(snapshot: store.snapshot.network, now: store.displayNow, surface: .overview)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent(language.text("Public IP"), value: language.text(store.snapshot.publicIP ?? "Unavailable"))
                        .labeledContentStyle(SummaryLabeledContentStyle(technicalValue: true))
                    LabeledContent(language.text("Region"), value: language.text(store.snapshot.region ?? "Unavailable"))
                    LabeledContent(language.text("Proxy"), value: language.text(store.snapshot.proxyHint))
                    LabeledContent(language.text("Tunnel hint"), value: language.text(store.snapshot.tunnelHint))
                    Divider()
                    ForEach(store.snapshot.serviceLatency, id: \.0) { item in
                        LabeledContent(language.text(item.0), value: language.text(item.1))
                    }
                }
                .font(MacSoulTheme.Typography.body)
                .labeledContentStyle(SummaryLabeledContentStyle())
            }
        }
    }

    private var devCard: some View {
        CardContainer(title: "Dev Environment", systemImage: "terminal",
                      badge: store.snapshot.devMode == .live ? "LIVE" : "MOCK", surface: .overview) {
            VStack(alignment: .leading, spacing: 12) {
                if store.snapshot.devMode == .live, let reading = store.snapshot.runtimeReading {
                    if reading.state == .sampling {
                        Text(language.text("Sampling…")).font(MacSoulTheme.Typography.status)
                    } else {
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                            ForEach(reading.records) { runtime in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(runtime.name).font(MacSoulTheme.Typography.fieldLabel)
                                    Text(language.text(runtime.primary?.version ?? runtime.status.label)).font(MacSoulTheme.Typography.fieldValue)
                                    Text(runtime.primary?.source ?? language.text("Current detection context"))
                                        .font(MacSoulTheme.Typography.supporting)
                                        .help(runtime.primary?.path ?? "")
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                        ForEach(store.snapshot.runtimes) { runtime in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(runtime.name).font(MacSoulTheme.Typography.fieldLabel)
                                Text(language.text(runtime.version)).font(MacSoulTheme.Typography.fieldValue)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Divider()
                Text(language.text(store.snapshot.devMode == .live
                    ? "Developer TCP Listeners" : "Listening Ports"))
                    .font(MacSoulTheme.Typography.fieldLabel)
                if store.snapshot.devMode == .live, let reading = store.snapshot.portReading {
                    if reading.state == .available || reading.state == .empty {
                        if reading.developerListeners.isEmpty {
                            Text(language.text("No developer TCP listeners found"))
                                .font(MacSoulTheme.Typography.supporting)
                        }
                        ForEach(reading.overviewListeners) { item in
                            Text(item.overviewSummary)
                                .font(MacSoulTheme.Typography.technical).fixedSize(horizontal: false, vertical: true)
                        }
                        if reading.developerListeners.count > 3 {
                            Text(language.text("More in Dev"))
                                .font(MacSoulTheme.Typography.supporting)
                        }
                    } else {
                        Text(language.text(reading.state.label)).font(MacSoulTheme.Typography.supporting)
                    }
                } else { FlowPortsView(ports: store.snapshot.ports) }
            }
        }
    }

    private var cleanerCard: some View {
        CardContainer(title: "Cleaner", assetImage: "CleanerBroom", surface: .overview) {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.cleanerText("Read only")).font(MacSoulTheme.Typography.status)
                if store.snapshot.cleaner.mode == .live {
                    Text(language.cleanerSummary(store.snapshot.cleaner)).font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                } else {
                    Text(language.text("MOCK") + " · " + language.cleanerText("Not scanned")).font(MacSoulTheme.Typography.status)
                }
                ForEach(store.snapshot.cleaner.mode == .mock ? store.snapshot.cleanerItems : []) { item in
                    HStack {
                        Text(item.name).font(MacSoulTheme.Typography.body)
                        Spacer()
                        Text(language.cleanerText(item.risk == .safe ? "Low risk" : item.risk == .caution ? "Caution" : "High risk"))
                            .font(MacSoulTheme.Typography.status)
                            .foregroundStyle(item.risk == .safe ? Color.primary : Color.orange)
                        Text(item.size).font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(ports) { item in
                Text("\(item.displayPort) · \(language.text(item.process))")
                    .font(MacSoulTheme.Typography.technical).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }
}
