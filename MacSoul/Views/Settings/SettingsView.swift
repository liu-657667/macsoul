import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section("Phase A · MOCK DATA") {
                LabeledContent("Live sampling", value: "Unavailable")
                LabeledContent("Quota providers", value: "Unavailable")
                LabeledContent("Cleaner actions", value: "Disabled")
            }
            #if DEBUG
            if let currentFixture = store.previewFixture {
                Section("Developer Preview · MOCK DATA") {
                    Picker("Fixture", selection: Binding(
                        get: { store.previewFixture ?? currentFixture },
                        set: { store.selectPreviewFixture($0) }
                    )) {
                        ForEach(MockProvider.Fixture.allCases) { fixture in
                            Text(fixture.label).tag(fixture)
                        }
                    }
                    Text("Changes the bundled mock snapshot only; no system or quota provider runs.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Menu Bar artwork · DRAFT") {
                HStack(spacing: 12) {
                    Image("MacSoulMenuTemplateDraft")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .accessibilityLabel("MacSoul menu icon draft at 18 points")
                    Text("18 pt draft is active in the menu bar; small-size review is pending.")
                }
            }
            #endif
            Text("This build is a mock preview. Settings are not active.")
                .foregroundStyle(.secondary)
        }.padding().navigationTitle("Settings")
    }
}
