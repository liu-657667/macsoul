import SwiftUI

struct AICodingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                    Text(language.text(store.snapshot.quotaMode == .mock ? "Quota Monitor · MOCK DATA" : "AI Coding · LIVE"))
                        .font(MacSoulTheme.Typography.sectionTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text(language.text(store.snapshot.quotaMode == .mock ? "Shows applicable 5-hour and 1-week remaining quota. No live provider is connected." : "Only reported provider windows are shown. Unavailable providers have no simulated quota."))
                        .font(MacSoulTheme.Typography.supporting).lineSpacing(2)
                }
                ForEach(store.snapshot.quotas) { quota in
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        Text(quota.provider.rawValue)
                            .font(MacSoulTheme.Typography.itemTitle)
                            .accessibilityAddTraits(.isHeader)
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.regular) {
                            Text("\(language.text("Mode")): \(language.text(quota.mode.rawValue))")
                                .font(MacSoulTheme.Typography.status)
                            QuotaRow(quota: quota, appearance: .aiDetail)
                            if let detail = store.snapshot.quotaDetails.first(where: { $0.provider == quota.provider }) {
                                Text("\(language.text("Status")): \(language.quotaStatus(detail))")
                                    .font(MacSoulTheme.Typography.status)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let version = detail.version {
                                    Text("CLI: " + version).font(MacSoulTheme.Typography.supporting)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(MacSoulTheme.Spacing.card)
                        .background(MacSoulTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: MacSoulTheme.Radius.card, style: .continuous))
                    }
                }
            }
            .frame(maxWidth: 820, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(MacSoulTheme.Spacing.section)
        }.navigationTitle(language.text("AI Coding"))
    }
}
