import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.macSoulLanguage) private var language
    @Environment(\.colorScheme) private var colorScheme
    var presentationMode: SystemMode? = nil
    private var snapshot: AppSnapshot { store.snapshot }
    private let metricColumns = [GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card),
                                 GridItem(.flexible(), spacing: MacSoulTheme.Spacing.card)]
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                Text("MacSoul").font(MacSoulTheme.Typography.itemTitle)
                SummaryModeLabel(mode: presentationMode ?? store.systemMode)
            }
            HStack(spacing: MacSoulTheme.Spacing.regular) {
                SoulArtwork(visual: snapshot.soulVisual, size: MacSoulTheme.Size.soulPopover, surface: .menuBar)
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                    Text(language.text(snapshot.soulMood)).font(MacSoulTheme.Typography.fieldValue)
                    Text(language.text(snapshot.soulMessage)).font(MacSoulTheme.Typography.supporting).fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            LazyVGrid(columns: metricColumns, spacing: MacSoulTheme.Spacing.regular) {
                MetricTile(name: "CPU", metric: snapshot.cpu, compact: true, surface: .menuBar)
                MetricTile(name: "Memory used", metric: snapshot.memoryUsed, compact: true, surface: .menuBar)
                MetricTile(name: "Disk", metric: snapshot.disk, compact: true,
                           emptyStateText: snapshot.diskEmptyState, surface: .menuBar)
                MetricTile(name: "Battery", metric: snapshot.battery, compact: true,
                           attentionText: snapshot.battery.usedPercent.map { $0 <= 10 ? "Low battery" : nil } ?? nil,
                           overrideLabel: snapshot.batterySummaryOverride,
                           emptyStateText: snapshot.batteryEmptyState, surface: .menuBar)
            }
            MemoryPressureLabel(pressure: snapshot.memoryPressure, surface: .menuBar)
            Divider()
            ForEach(snapshot.quotas) { quota in
                QuotaRow(quota: quota, presentation: .summary, appearance: .menuBarSummary)
            }
            Divider()
            if snapshot.networkMode == .live {
                NetworkSummary(snapshot: snapshot.network, now: store.displayNow, compact: true, surface: .menuBar)
            } else {
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    LabeledContent(language.text("IP"), value: language.text(snapshot.publicIP ?? "Unavailable"))
                        .labeledContentStyle(SummaryLabeledContentStyle(technicalValue: true))
                    LabeledContent(language.text("Proxy"), value: language.text(snapshot.proxyHint))
                    LabeledContent(language.text("Tunnel"), value: language.text(snapshot.tunnelHint))
                }.labeledContentStyle(SummaryLabeledContentStyle())
            }
            Divider()
            HStack {
                Button(language.text("Open MacSoul")) { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
                Spacer()
                Button(language.text("Quit MacSoul")) { NSApplication.shared.terminate(nil) }
            }.font(MacSoulTheme.Typography.body)
        }
        .padding(MacSoulTheme.Spacing.card)
        .frame(width: 390)
        .background(Color(nsColor: MacSoulTheme.windowBackgroundColor(for: colorScheme)).ignoresSafeArea())
    }
}
