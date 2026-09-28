import SwiftUI

enum QuotaPresentation: Equatable {
    case summary, detail
}

struct QuotaRow: View {
    @Environment(\.macSoulLanguage) private var language
    let quota: QuotaItem
    var presentation: QuotaPresentation = .detail

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
                if presentation == .detail {
                    Text(language.text(quota.mode.rawValue))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(quota.displayWindows(now: now)) { window in
                QuotaWindowView(window: window, now: now, presentation: presentation)
            }
            if presentation == .detail {
                ForEach(quota.notApplicableLabels(), id: \.self) { label in
                    Text("\(language.text(label)): \(language.text("Not applicable"))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Text("\(language.text("Source")): \(language.text(quota.source)) · \(language.text("Updated")): \(quota.sampledAt.map { fullTime($0) } ?? "—")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func fullTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(language.locale))
    }
}

struct QuotaWindowView: View {
    @Environment(\.macSoulLanguage) private var language
    let window: QuotaDisplayWindow
    let now: Date
    let presentation: QuotaPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
            HStack {
                Text(language.text(window.kind.label)).foregroundStyle(.secondary)
                Spacer()
                if isAbnormal {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .accessibilityHidden(true)
                }
                Text(statusLabel).fontWeight(isAbnormal ? .semibold : .regular)
                if presentation == .detail, let value = window.state.value {
                    Text(fullResetLabel(for: value)).foregroundStyle(.secondary)
                }
            }.font(.caption)
            if let value = window.state.value {
                ProgressView(value: value.usedPercent / 100)
            }
        }
    }

    private var isAbnormal: Bool {
        switch window.state {
        case .stale, .requestFailed, .providerUnavailable: true
        default: false
        }
    }

    private var statusLabel: String {
        switch window.state {
        case .fresh(let value):
            let used = language.used(Int(value.usedPercent.rounded()))
            if presentation == .summary, let reset = value.resetsAt {
                return "\(used) · \(Self.shortResetLabel(reset: reset, now: now, language: language))"
            }
            return presentation == .detail ? "\(used) · \(language.text("Fresh"))" : used
        case .stale(let value): return "\(language.used(Int(value.usedPercent.rounded()))) · \(language.text("Stale"))"
        case .unreported: return language.text("Not reported")
        case .requestFailed: return language.text("Request failed")
        case .providerUnavailable: return language.text("Quota unavailable")
        }
    }

    static func shortResetLabel(reset: Date, now: Date, language: MacSoulLanguage = .english) -> String {
        let seconds = Int(ceil(reset.timeIntervalSince(now)))
        guard seconds > 0 else { return language == .english ? "refresh pending" : "等待刷新" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60
        if days > 0 {
            return language == .english ? "reset in \(days)d \(hours)h" : "\(days)天\(hours)小时后重置"
        }
        if hours > 0 {
            return language == .english ? "reset in \(hours)h \(minutes)m" : "\(hours)小时\(minutes)分钟后重置"
        }
        let remainingMinutes = max(1, Int(ceil(Double(seconds) / 60)))
        return language == .english ? "reset in \(remainingMinutes)m" : "\(remainingMinutes)分钟后重置"
    }

    private func fullResetLabel(for value: QuotaWindow) -> String {
        guard let reset = value.resetsAt else { return language == .english ? "· Reset —" : "· 重置时间未知" }
        if reset <= now { return language == .english ? "· Reset due; awaiting refresh" : "· 重置时间已到，等待刷新" }
        let formatted = reset.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(language.locale))
        return language == .english ? "· Reset \(formatted)" : "· \(formatted) 重置"
    }
}
