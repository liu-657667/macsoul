import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    @AppStorage("macsoul.appearance") private var appearance = MacSoulAppearance.system.rawValue
    @AppStorage("macsoul.language") private var selectedLanguage = MacSoulLanguage.english.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                GroupBox(language.text("Current build capabilities")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        LabeledContent(language.text("Data mode"), value: language.text(store.systemMode == .live ? "Partial Live + Mock" : "Bundled Mock"))
                        LabeledContent(language.text("Live system sampling"), value: language.text(store.systemMode == .live ? "CPU and memory only" : "Not connected"))
                        LabeledContent(language.text("Live quota providers"), value: language.text("Not connected"))
                        LabeledContent(language.text("Cleaner deletion"), value: language.text("Not available"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(language.text("System data source")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        Picker(language.text("Mode"), selection: Binding(
                            get: { store.systemMode },
                            set: { store.setSystemMode($0) }
                        )) {
                            ForEach(SystemMode.allCases) { option in
                                Text(language.text(option.label)).tag(option)
                            }
                        }
                        .frame(maxWidth: 440, alignment: .leading)
                        Text(language.text("Live System uses native CPU and memory only. Other sections keep Mock data."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(language.text("App appearance")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        Picker(language.text("Appearance"), selection: $appearance) {
                            ForEach(MacSoulAppearance.allCases) { option in
                                Text(language.text(option.label)).tag(option.rawValue)
                            }
                        }
                        .frame(maxWidth: 440, alignment: .leading)
                        Text(language.text("Changes MacSoul windows only; the macOS appearance stays as it is."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(language == .english ? "Language" : "语言") {
                    Picker(language == .english ? "Language" : "语言", selection: $selectedLanguage) {
                        ForEach(MacSoulLanguage.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .frame(maxWidth: 440, alignment: .leading)
                }
                #if DEBUG
                if store.systemMode == .preview, let currentFixture = store.previewFixture {
                    GroupBox(language.text("Developer preview scenarios")) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                            Picker(language.text("Fixture"), selection: Binding(
                                get: { store.previewFixture ?? currentFixture },
                                set: { store.selectPreviewFixture($0) }
                            )) {
                                ForEach(MockProvider.Fixture.allCases) { fixture in
                                    Text(language.text(fixture.label)).tag(fixture)
                                }
                            }
                            .frame(maxWidth: 440, alignment: .leading)
                            Text(language.text("The fixture selector changes local demo data. It does not enable live collection or account access."))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                GroupBox(language.text("Menu Bar artwork · DRAFT")) {
                    HStack(spacing: MacSoulTheme.Spacing.regular) {
                        Image("MacSoulMenuTemplateDraft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .accessibilityLabel("MacSoul menu icon draft at 18 points")
                        Text(language.text("18 pt template candidate is active; small-size artwork remains DRAFT."))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                #endif
            }
            .frame(maxWidth: 680, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(MacSoulTheme.Spacing.section)
        }
        .navigationTitle(language.text("Settings"))
    }
}
