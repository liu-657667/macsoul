import SwiftUI

struct QuotaRow: View {
    let quota: QuotaItem
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack {
                Text(quota.provider.rawValue).font(.headline)
                Spacer()
                Text("\(quota.mode.rawValue) · \(quota.effectiveFreshness(now: now).rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            QuotaWindowView(label: "5h", window: quota.fiveHour, now: now)
            QuotaWindowView(label: "1 week", window: quota.weekly, now: now)
            Text("Source: \(quota.source) · Updated: \(quota.sampledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct QuotaWindowView: View {
    let label: String
    let window: QuotaWindow?
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(window.map { "\(Int($0.usedPercent.rounded()))% used" } ?? "Unavailable")
                Text(resetLabel).foregroundStyle(.secondary)
            }.font(.caption)
            if let window { ProgressView(value: window.usedPercent / 100) }
        }
    }
    private var resetLabel: String {
        guard let reset = window?.resetsAt else { return "· Reset —" }
        return "· Reset \(reset.formatted(date: .abbreviated, time: .shortened))\(reset <= now ? " (expired)" : "")"
    }
}
