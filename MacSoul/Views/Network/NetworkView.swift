import SwiftUI

struct NetworkView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    var body: some View {
        Form {
            Section(language.text("Network · MOCK DATA")) {
                LabeledContent(language.text("Public IP"), value: language.text(store.snapshot.publicIP ?? "Unavailable"))
                LabeledContent(language.text("Region"), value: language.text(store.snapshot.region ?? "Unavailable"))
                LabeledContent(language.text("Proxy hint"), value: language.text(store.snapshot.proxyHint))
                LabeledContent(language.text("Tunnel hint"), value: language.text(store.snapshot.tunnelHint))
            }
            Text(language.text("No external probe is connected.")).foregroundStyle(.secondary)
        }.padding().navigationTitle(language.text("Network"))
    }
}
