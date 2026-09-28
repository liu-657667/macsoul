import SwiftUI

struct MetricTile: View {
    @Environment(\.macSoulLanguage) private var language
    let name: String
    let metric: PercentMetric
    var compact = false

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

    private var content: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack(alignment: .firstTextBaseline, spacing: MacSoulTheme.Spacing.tight) {
                Text(language.text(name))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: MacSoulTheme.Spacing.tight)
                Text(metric.label)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            if let progress = metric.progress { ProgressView(value: progress).progressViewStyle(.linear) }
            else { Text(language.text("Unavailable")).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
