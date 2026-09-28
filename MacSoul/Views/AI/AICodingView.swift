import SwiftUI

struct AICodingView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(language.text("Quota Monitor · MOCK DATA")).font(.title2.bold())
                Text(language.text("Shows applicable 5-hour and 1-week used quota. No live provider is connected."))
                    .foregroundStyle(.secondary)
                ForEach(store.snapshot.quotas) { quota in
                    CardContainer(title: quota.provider.rawValue, systemImage: "sparkles") {
                        QuotaRow(quota: quota)
                    }
                }
            }.padding(24)
        }.navigationTitle(language.text("AI Coding"))
    }
}
