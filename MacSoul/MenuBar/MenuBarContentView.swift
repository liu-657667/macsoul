import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.macSoulLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    private var snapshot: AppSnapshot { store.snapshot }
    private let metricColumns = [GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card),
                                 GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card)]
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack {
                Text("MacSoul").fontWeight(.semibold)
                Spacer()
                Text(language.text(store.systemMode == .live ? "CPU / MEMORY LIVE · OTHER MOCK" : "MOCK DATA"))
                    .font(.caption.bold()).foregroundStyle(.orange)
            }
            HStack(spacing: MacSoulTheme.Spacing.regular) {
                SoulArtwork(visual: snapshot.soulVisual, size: MacSoulTheme.Size.soulPopover)
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                    Text(language.text(snapshot.soulMood)).fontWeight(.semibold)
                    Text(language.text(snapshot.soulMessage)).font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                }
            }
            Divider()
            LazyVGrid(columns: metricColumns, spacing: MacSoulTheme.Spacing.regular) {
                MetricTile(name: "CPU", metric: snapshot.cpu, compact: true)
                MetricTile(name: "Memory used", metric: snapshot.memoryUsed, compact: true)
                MetricTile(name: "Disk", metric: snapshot.disk, compact: true)
                MetricTile(name: "Battery", metric: snapshot.battery, compact: true,
                           attentionText: snapshot.battery.usedPercent.map { $0 <= 10 ? "Low battery" : nil } ?? nil)
            }
            MemoryPressureLabel(pressure: snapshot.memoryPressure)
            if store.systemMode == .live {
                Text(language.text("CPU and memory: Live · Disk and battery: Mock"))
                    .font(.caption2).foregroundStyle(MacSoulTheme.supportingText)
            }
            Divider()
            ForEach(snapshot.quotas) { quota in
                QuotaRow(quota: quota, presentation: .summary)
            }
            Divider()
            LabeledContent(language.text("IP"), value: language.text(snapshot.publicIP ?? "Unavailable")).font(.caption)
            LabeledContent(language.text("Proxy"), value: language.text(snapshot.proxyHint)).font(.caption)
            LabeledContent(language.text("Tunnel"), value: language.text(snapshot.tunnelHint)).font(.caption)
            Divider()
            HStack {
                Button(language.text("Open MacSoul")) { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
                Spacer()
                Button(language.text("Quit MacSoul")) { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(MacSoulTheme.Spacing.card)
        .frame(width: 390)
        .background(Color(nsColor: MacSoulTheme.windowBackgroundColor(for: colorScheme)).ignoresSafeArea())
    }
}
