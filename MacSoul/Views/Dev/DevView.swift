import SwiftUI

struct DevView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        Form {
            Section(language.text("Runtimes — Mock")) {
                ForEach(store.snapshot.runtimes) { runtime in
                    LabeledContent(runtime.name, value: language.text(runtime.version))
                }
            }
            Section(language.text("Listening Ports — Mock")) {
                ForEach(store.snapshot.ports) { item in
                    LabeledContent(item.displayPort, value: language.text(item.process))
                }
            }
        }
        .padding()
        .navigationTitle(language.text("Dev"))
    }
}
