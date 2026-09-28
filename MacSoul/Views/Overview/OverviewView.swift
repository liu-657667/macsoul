import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: AppStore

    private let columns = [
        GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card),
        GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                header
                LazyVGrid(columns: columns, spacing: MacSoulTheme.Spacing.card) {
                    soulCard
                    systemCard
                    aiCard
                    networkCard
                    devCard
                    cleanerCard
                }
            }
            .padding(MacSoulTheme.Spacing.section)
        }
        .navigationTitle("Overview")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            Text("MacSoul")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("MOCK DATA · No live sampling or quota provider")
                .foregroundStyle(.secondary)
        }
    }

    private var soulCard: some View {
        CardContainer(title: "Soul", systemImage: "brain.head.profile") {
            HStack(spacing: MacSoulTheme.Spacing.card) {
                SoulGlyph()
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(store.snapshot.soulMood)
                        .font(.title3.bold())
                    Text(store.snapshot.soulMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var systemCard: some View {
        CardContainer(title: "System", systemImage: "gauge.with.dots.needle.50percent") {
            VStack(spacing: 10) {
                MetricTile(name: "CPU", metric: store.snapshot.cpu)
                MetricTile(name: "Memory used", metric: store.snapshot.memoryUsed)
                MetricTile(name: "Disk", metric: store.snapshot.disk)
                MetricTile(name: "Battery", metric: store.snapshot.battery)
            }
        }
    }

    private var aiCard: some View {
        CardContainer(title: "AI Coding", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(store.snapshot.quotas) { quota in
                    QuotaRow(quota: quota, now: Date())
                    if quota.id != store.snapshot.quotas.last?.id { Divider() }
                }
            }
        }
    }

    private var networkCard: some View {
        CardContainer(title: "Network", systemImage: "network") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Public IP", value: (store.snapshot.publicIP ?? "Unavailable"))
                LabeledContent("Region", value: (store.snapshot.region ?? "Unavailable"))
                LabeledContent("Proxy", value: store.snapshot.proxyHint)
                LabeledContent("Tunnel hint", value: store.snapshot.tunnelHint)
                Divider()
                ForEach(store.snapshot.serviceLatency, id: \.0) { item in
                    LabeledContent(item.0, value: item.1)
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
                            Text(runtime.version).fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()
                Text("Listening Ports")
                    .foregroundStyle(.secondary)
                FlowPortsView(ports: store.snapshot.ports)
            }
        }
    }

    private var cleanerCard: some View {
        CardContainer(title: "Cleaner", systemImage: "broom") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Read-only scan")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Not run")
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
    let ports: [PortItem]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(ports) { item in
                Text("\(item.port) · \(item.process)")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Capsule())
            }
        }
    }
}
