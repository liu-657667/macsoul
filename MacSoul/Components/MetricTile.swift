import SwiftUI

struct MetricTile: View {
    @Environment(\.macSoulLanguage) private var language
    let name: String
    let metric: PercentMetric
    var compact = false
    var attentionText: String? = nil
    var overrideLabel: String? = nil
    var emptyStateText = "Unavailable"
    var surface: SummarySurface = .standard

    @ViewBuilder var body: some View {
        if compact {
            content
        } else {
            content
                .padding(MacSoulTheme.Spacing.regular)
                .background(Color.primary.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: MacSoulTheme.Radius.tile, style: .continuous))
        }
    }

    @ViewBuilder private var content: some View {
        if surface == .standard { standardContent } else { summaryContent }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.tight) {
                Text(language.text(name)).font(MacSoulTheme.Typography.fieldLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MacSoulTheme.Spacing.compact)
                Text(language.text(overrideLabel ?? metric.label))
                    .font(MacSoulTheme.Typography.fieldValue).monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false).layoutPriority(1)
            }
            if let progress = metric.progress { ProgressView(value: progress).progressViewStyle(.linear) }
            else if overrideLabel == nil {
                Text(language.text(emptyStateText)).font(MacSoulTheme.Typography.supporting)
            }
            if let attentionText {
                Label(language.text(attentionText), systemImage: "exclamationmark.triangle.fill")
                    .font(MacSoulTheme.Typography.status).foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text(name))
        .accessibilityValue(AccessibilityPresentation.metricValue(metric: metric, language: language,
            override: overrideLabel, empty: emptyStateText, attention: attentionText))
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.tight) {
                Text(language.text(name))
                    .foregroundStyle(MacSoulTheme.supportingText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: MacSoulTheme.Spacing.tight)
                Text(language.text(overrideLabel ?? metric.label))
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            if let progress = metric.progress { ProgressView(value: progress).progressViewStyle(.linear) }
            else if overrideLabel == nil {
                Text(language.text(emptyStateText)).font(.caption).foregroundStyle(.secondary)
            }
            if let attentionText {
                Label(language.text(attentionText), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text(name))
        .accessibilityValue(AccessibilityPresentation.metricValue(metric: metric, language: language,
            override: overrideLabel, empty: emptyStateText, attention: attentionText))
    }
}

struct MemoryPressureLabel: View {
    @Environment(\.macSoulLanguage) private var language
    let pressure: String
    var surface: SummarySurface = .standard

    private var text: String {
        let summary = pressure == "Unknown · Live" ? "Monitoring · Live" : pressure
        return language == .english ? "Pressure: \(language.text(summary))" : "内存压力：\(language.text(summary))"
    }

    var body: some View {
        Group {
            if pressure == "Critical · Mock" || pressure == "Critical · Live" || pressure == "Warning · Live" {
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            } else {
                Text(text).foregroundStyle(MacSoulTheme.supportingText)
            }
        }
        .font(surface == .standard ? .caption : MacSoulTheme.Typography.status)
    }
}
