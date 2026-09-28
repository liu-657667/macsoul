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
            Text(language.text("MOCK DATA · No live sampling or quota provider"))
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
                    MetricTile(name: "Disk", metric: store.snapshot.disk, compact: true)
                    MetricTile(name: "Battery", metric: store.snapshot.battery, compact: true,
                               attentionText: store.snapshot.battery.usedPercent.map { $0 <= 10 ? "Low battery" : nil } ?? nil)
                }
                MemoryPressureLabel(pressure: store.snapshot.memoryPressure)
            }
        }
    }

    private var aiCard: some View {
        CardContainer(title: "AI Coding", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.snapshot.quotas) { quota in
                    QuotaRow(quota: quota, presentation: .summary)
                    if quota.id != store.snapshot.quotas.last?.id { Divider() }
                }
            }
        }
    }

    private var networkCard: some View {
        CardContainer(title: "Network", systemImage: "network") {
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

    private var devCard: some View {
        CardContainer(title: "Dev Environment", systemImage: "terminal") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(store.snapshot.runtimes) { runtime in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(runtime.name).foregroundStyle(.secondary)
                            Text(language.text(runtime.version)).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()
                Text(language.text("Listening Ports"))
                    .foregroundStyle(.secondary)
                FlowPortsView(ports: store.snapshot.ports)
            }
        }
    }

    private var cleanerCard: some View {
        CardContainer(title: "Cleaner", assetImage: "CleanerBroom") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(language.text("Read-only scan"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(language.text("Not run"))
                        .font(.title3.bold())
                }
                ForEach(store.snapshot.cleanerItems) { item in
                    HStack {
                        Text(item.name)
                        Spacer()
                        Text(item.risk.rawValue)
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
