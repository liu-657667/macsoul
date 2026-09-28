import SwiftUI

struct CleanerView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleaner scan not run")
                .font(.title2.bold())
            Text("Day 1 uses mock values. Real scanning is intentionally disabled.")
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
        .navigationTitle("Cleaner")
    }
}
