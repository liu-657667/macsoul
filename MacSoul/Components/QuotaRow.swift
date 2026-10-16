import SwiftUI

enum QuotaPresentation: Equatable {
    case summary, detail
}

// Only the AI detail page opts in; shared summaries keep their existing layout.
enum QuotaRowAppearance: Equatable {
    case standard, aiDetail, overviewSummary, menuBarSummary

    func usesSummaryTypography(presentation: QuotaPresentation) -> Bool {
        presentation == .summary && (self == .overviewSummary || self == .menuBarSummary)
    }

    func showsProviderHeader(presentation: QuotaPresentation) -> Bool {
        self != .aiDetail || presentation != .detail
    }
}

struct QuotaRow: View {
    @Environment(\.macSoulLanguage) private var language
    @EnvironmentObject private var store: AppStore
    let quota: QuotaItem
    var presentation: QuotaPresentation = .detail
    var appearance: QuotaRowAppearance = .standard

    private var usesDetailTypography: Bool { appearance == .aiDetail && presentation == .detail }
    private var usesSummaryTypography: Bool { appearance.usesSummaryTypography(presentation: presentation) }

    var body: some View {
        content(now: store.displayNow)
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            if appearance.showsProviderHeader(presentation: presentation) {
                HStack {
                    Text(quota.provider.rawValue)
                        .font(usesSummaryTypography ? (appearance == .menuBarSummary ? MacSoulTheme.Typography.fieldValue : MacSoulTheme.Typography.itemTitle) : .headline)
                    Spacer()
                    if presentation == .detail {
                        Text(language.text(quota.badge))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if quota.entirelyUnavailable {
                if usesDetailTypography || usesSummaryTypography {
                    Text(language.text("Quota unavailable")).font(MacSoulTheme.Typography.status)
                } else {
                    Text(language.text("Quota unavailable")).font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                }
            } else {
                if presentation == .summary && quota.presentationWindows(now: now, presentation: presentation).isEmpty {
                    Text(language.text("Not reported")).font(usesSummaryTypography ? MacSoulTheme.Typography.status : .caption).foregroundStyle(usesSummaryTypography ? .primary : MacSoulTheme.supportingText)
                }
                ForEach(quota.presentationWindows(now: now, presentation: presentation)) { window in
                    QuotaWindowView(window: window, now: now, presentation: presentation, appearance: appearance)
                }
            }
            if presentation == .summary,
               let detail = store.snapshot.quotaDetails.first(where: { $0.provider == quota.provider }),
               detail.connection != .available && detail.connection != .stopped {
                Text(language.quotaStatus(detail)).font(usesSummaryTypography ? MacSoulTheme.Typography.status : .caption).foregroundStyle(.orange)
            }
            if presentation == .detail {
                ForEach(quota.notApplicableLabels(), id: \.self) { label in
                    Text("\(language.text(label)): \(language.text("Not applicable"))")
                        .font(usesDetailTypography ? MacSoulTheme.Typography.supporting : .caption2)
                        .foregroundStyle(usesDetailTypography ? .primary : .secondary)
                }
                if usesDetailTypography {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
                        Text("\(language.text("Source")): \(sourceLabel)")
                        Text("\(language.text("Updated")): \(quota.sampledAt.map { fullTime($0) } ?? "—")")
                    }
                    .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(language.text("Source")): \(sourceLabel) · \(language.text("Updated")): \(quota.sampledAt.map { fullTime($0) } ?? "—")")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sourceLabel: String {
        let detail = store.snapshot.quotaDetails.first { $0.provider == quota.provider }
        return quota.presentationSource(detail: detail).map { language.text($0) } ?? "—"
    }

    private func fullTime(_ date: Date) -> String {
        language.dateTime(date)
    }
}

struct QuotaWindowView: View {
    @Environment(\.macSoulLanguage) private var language
    let window: QuotaDisplayWindow
    let now: Date
    let presentation: QuotaPresentation
    var appearance: QuotaRowAppearance = .standard

    private var usesDetailTypography: Bool { appearance == .aiDetail && presentation == .detail }
    private var usesSummaryTypography: Bool { appearance.usesSummaryTypography(presentation: presentation) }

    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.compact) {
            if usesDetailTypography {
                HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(window.kind.label)).font(MacSoulTheme.Typography.fieldLabel)
                    Spacer()
                    if isAbnormal {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).accessibilityHidden(true)
                    }
                    Text(Self.statusLabel(for: window, now: now, language: language, presentation: presentation))
                        .font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                }
                if let value = window.state.value {
                    Text(fullResetLabel(for: value, inlineSeparator: false))
                        .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if usesSummaryTypography {
                HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(window.kind.label)).font(MacSoulTheme.Typography.fieldLabel)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: MacSoulTheme.Spacing.compact)
                    if isAbnormal {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).accessibilityHidden(true)
                    }
                    Text(Self.statusLabel(for: window, now: now, language: language, presentation: presentation))
                        .font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                        .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack {
                    Text(language.text(window.kind.label)).foregroundStyle(MacSoulTheme.supportingText)
                    Spacer()
                    if isAbnormal {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                    Text(Self.statusLabel(for: window, now: now, language: language, presentation: presentation))
                        .fontWeight(isAbnormal ? .semibold : .regular)
                    if presentation == .detail, let value = window.state.value {
                        Text(fullResetLabel(for: value)).foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            if let value = window.state.value {
                ProgressView(value: value.remainingProgress)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text(window.kind.label))
        .accessibilityValue(AccessibilityPresentation.quotaValue(window: window, now: now,
            language: language, presentation: presentation)
            + (presentation == .detail ? window.state.value.map { " " + fullResetLabel(for: $0) } ?? "" : ""))
    }

    private var isAbnormal: Bool {
        switch window.state {
        case .stale, .requestFailed, .providerUnavailable: true
        case .fresh(let value): value.usedPercent >= 95
        default: false
        }
    }

    static func statusLabel(for window: QuotaDisplayWindow, now: Date, language: MacSoulLanguage,
                            presentation: QuotaPresentation) -> String {
        switch window.state {
        case .fresh(let value):
            let remaining = language.remaining(Int(value.remainingPercent.rounded()))
            let valueLabel = value.usedPercent >= 95 ? "\(language.text("Near limit")) · \(remaining)" : remaining
            if presentation == .summary, let reset = value.resetsAt {
                return "\(valueLabel) · \(Self.shortResetLabel(reset: reset, now: now, language: language))"
            }
            return presentation == .detail ? "\(valueLabel) · \(language.text("Fresh"))" : valueLabel
        case .stale(let value): return "\(language.remaining(Int(value.remainingPercent.rounded()))) · \(language.text("Stale"))"
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

    private func fullResetLabel(for value: QuotaWindow, inlineSeparator: Bool = true) -> String {
        Self.resetLabel(for: value, now: now, language: language, inlineSeparator: inlineSeparator)
    }

    static func resetLabel(for value: QuotaWindow, now: Date, language: MacSoulLanguage,
                           inlineSeparator: Bool = true) -> String {
        let prefix = inlineSeparator ? "· " : ""
        guard let reset = value.resetsAt else { return prefix + (language == .english ? "Reset —" : "重置时间未知") }
        if reset <= now { return prefix + (language == .english ? "Reset due; awaiting refresh" : "重置时间已到，等待刷新") }
        let formatted = reset.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(language.locale))
        return prefix + (language == .english ? "Reset \(formatted)" : "\(formatted) 重置")
    }
}
