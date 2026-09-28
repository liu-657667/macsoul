import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("Network · MOCK DATA") {
                LabeledContent("Public IP", value: store.snapshot.publicIP ?? "Unavailable")
                LabeledContent("Region", value: store.snapshot.region ?? "Unavailable")
                LabeledContent("Proxy hint", value: store.snapshot.proxyHint)
                LabeledContent("Tunnel hint", value: store.snapshot.tunnelHint)
            }
            Text("No external probe is connected.").foregroundStyle(.secondary)
        }.padding().navigationTitle("Network")
    }
}
