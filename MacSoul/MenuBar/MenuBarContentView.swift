import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openWindow) private var openWindow
    private var snapshot: AppSnapshot { store.snapshot }
    private let metricColumns = [GridItem(.flexible(), spacing: MacSoulTheme.Spacing.compact),
                                 GridItem(.flexible(), spacing: MacSoulTheme.Spacing.compact)]
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
            HStack {
                Text("MacSoul").fontWeight(.semibold)
                Spacer()
                Text("MOCK DATA").font(.caption.bold()).foregroundStyle(.orange)
            }
            HStack(spacing: MacSoulTheme.Spacing.regular) {
                SoulArtwork(visual: snapshot.soulVisual, size: MacSoulTheme.Size.soulPopover)
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                    Text(snapshot.soulMood).fontWeight(.semibold)
                    Text(snapshot.soulMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            LazyVGrid(columns: metricColumns, spacing: MacSoulTheme.Spacing.compact) {
                MetricTile(name: "CPU", metric: snapshot.cpu)
                MetricTile(name: "Memory used", metric: snapshot.memoryUsed)
                MetricTile(name: "Disk", metric: snapshot.disk)
                MetricTile(name: "Battery", metric: snapshot.battery)
            }
            Text("Pressure: \(snapshot.memoryPressure)").font(.caption).foregroundStyle(.secondary)
            Divider()
            ForEach(snapshot.quotas) { quota in
                QuotaRow(quota: quota)
            }
            Divider()
            LabeledContent("IP", value: snapshot.publicIP ?? "Unavailable").font(.caption)
            LabeledContent("Proxy", value: snapshot.proxyHint).font(.caption)
            LabeledContent("Tunnel", value: snapshot.tunnelHint).font(.caption)
            Divider()
            Button("Open MacSoul") { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
            Button("Quit MacSoul") { NSApplication.shared.terminate(nil) }
        }
        .padding(MacSoulTheme.Spacing.card)
        .frame(width: 390)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
