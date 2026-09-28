import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openWindow) private var openWindow
    private var snapshot: AppSnapshot { store.snapshot }
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
            HStack {
                Text("MacSoul").fontWeight(.semibold)
                Spacer()
                Text("MOCK DATA").font(.caption.bold()).foregroundStyle(.orange)
            }
            Text(snapshot.soulMessage).font(.caption).foregroundStyle(.secondary)
            Divider()
            MetricTile(name: "CPU", metric: snapshot.cpu)
            MetricTile(name: "Memory used", metric: snapshot.memoryUsed)
            Text("Pressure: \(snapshot.memoryPressure)").font(.caption).foregroundStyle(.secondary)
            Divider()
            ForEach(snapshot.quotas) { quota in
                QuotaRow(quota: quota, now: Date())
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
    }
}
