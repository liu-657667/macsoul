import SwiftUI

struct DevView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("Runtimes — Mock") {
                ForEach(store.snapshot.runtimes) { runtime in
                    LabeledContent(runtime.name, value: runtime.version)
                }
            }
            Section("Listening Ports — Mock") {
                ForEach(store.snapshot.ports) { item in
                    LabeledContent("\(item.port)", value: item.process)
                }
            }
        }
        .padding()
        .navigationTitle("Dev")
    }
}
