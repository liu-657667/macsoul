import SwiftUI

struct AICodingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(language.text(store.snapshot.quotaMode == .mock ? "Quota Monitor · MOCK DATA" : "AI Coding · LIVE")).font(.title2.bold())
                Text(language.text(store.snapshot.quotaMode == .mock ? "Shows applicable 5-hour and 1-week remaining quota. No live provider is connected." : "Only reported provider windows are shown. Unavailable providers have no simulated quota."))
                    .foregroundStyle(.secondary)
                ForEach(store.snapshot.quotas) { quota in
                    CardContainer(title: quota.provider.rawValue, systemImage: "sparkles", badge: quota.badge) {
                        VStack(alignment: .leading, spacing: 8) {
                            QuotaRow(quota: quota)
                            if let detail = store.snapshot.quotaDetails.first(where: { $0.provider == quota.provider }) {
                                Text(language.quotaStatus(detail)).font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                                if let version = detail.version { Text("CLI: " + version).font(.caption2).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }.padding(24)
        }.navigationTitle(language.text("AI Coding"))
    }
}
