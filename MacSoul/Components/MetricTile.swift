import SwiftUI

struct MetricTile: View {
    let name: String
    let metric: PercentMetric
    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
            HStack {
                Text(name).foregroundStyle(.secondary)
                Spacer()
                Text(metric.label).fontWeight(.semibold)
            }
            if let progress = metric.progress { ProgressView(value: progress).progressViewStyle(.linear) }
            else { Text("Unavailable").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(MacSoulTheme.Spacing.regular)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: MacSoulTheme.Radius.tile, style: .continuous))
    }
}
