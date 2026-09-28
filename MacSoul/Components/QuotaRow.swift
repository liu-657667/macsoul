import SwiftUI

struct QuotaRow: View {
    let quota: QuotaItem
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack {
                Text(quota.provider.rawValue).font(.headline)
                Spacer()
                Text(quota.mode.rawValue)
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(quota.displayWindows(now: now)) { window in
                QuotaWindowView(window: window, now: now)
            }
            ForEach(quota.notApplicableLabels(), id: \.self) { label in
                Text("\(label): Not applicable")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text("Source: \(quota.source) · Updated: \(quota.sampledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "—")")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct QuotaWindowView: View {
    let window: QuotaDisplayWindow
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
            HStack {
                Text(window.kind.label).foregroundStyle(.secondary)
                Spacer()
                Text(statusLabel)
                if let value = window.state.value {
                    Text(resetLabel(for: value)).foregroundStyle(.secondary)
                }
            }.font(.caption)
            if let value = window.state.value {
                ProgressView(value: value.usedPercent / 100)
            }
        }
    }
    private var statusLabel: String {
        switch window.state {
        case .fresh(let value): "\(Int(value.usedPercent.rounded()))% used · Fresh"
        case .stale(let value): "\(Int(value.usedPercent.rounded()))% used · Stale"
        case .unreported: "Not reported"
        case .requestFailed: "Request failed"
        case .providerUnavailable: "Quota unavailable"
        }
    }
    private func resetLabel(for value: QuotaWindow) -> String {
        guard let reset = value.resetsAt else { return "· Reset —" }
        if reset <= now { return "· Reset due; awaiting refresh" }
        return "· Reset \(reset.formatted(date: .abbreviated, time: .shortened))"
    }
}
