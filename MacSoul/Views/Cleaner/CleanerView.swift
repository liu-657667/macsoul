import SwiftUI

struct CleanerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("Cleaner scan not run"))
                .font(.title2.bold())
            Text(language.text("Day 1 uses mock values. Real scanning is intentionally disabled."))
                .foregroundStyle(.secondary)
            List(store.snapshot.cleanerItems) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.name)
                        Text(item.risk.rawValue)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.size)
                }
            }
        }
        .padding(24)
        .navigationTitle(language.text("Cleaner"))
    }
}
