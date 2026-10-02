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
                        LabeledContent(language.text("Live system sampling"), value: language.text(store.systemMode == .live ? "CPU, memory, disk, battery, processes" : "Not connected"))
                        LabeledContent(language.text("Live developer environment"), value: language.text(store.systemMode == .live ? "Runtimes and TCP listeners" : "Not connected"))
                        LabeledContent(language.text("Live network monitoring"), value: language.text(store.systemMode == .live ? "Path, public IP, proxy, tunnel hints, connectivity" : "Not connected"))
                        LabeledContent(language.text("Live quota providers"), value: language.text("Not connected"))
                        LabeledContent(language.text("Cleaner"), value: language.cleanerText(store.systemMode == .live ? "Read only" : "Preview uses Mock fixtures; no filesystem scan runs."))
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
                        Text(language.text("Live mode includes System, Dev Environment and Network. AI remains Mock."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox(language.text("Network external requests")) {
                    HStack(alignment: .top, spacing: MacSoulTheme.Spacing.card) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                            Text(language.text("Connectivity probes"))
                            Text(language.text("In Live mode, probes send minimal HTTPS requests to GitHub, OpenAI and Anthropic. No account credentials or project data are sent. Turning probes off cancels pending probes."))
                                .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                            Text(language.text("Live mode also queries ipify for public IPv4/IPv6. Developer Preview sends no external network requests."))
                                .font(.caption).foregroundStyle(MacSoulTheme.supportingText)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Toggle(language.text("Connectivity probes"), isOn: Binding(
                            get: { store.connectivityEnabled }, set: { store.setConnectivityEnabled($0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel(language.text("Connectivity probes"))
                            .accessibilityHint(language.text("Turning probes off cancels pending connectivity probes."))
                    }.frame(maxWidth: .infinity, alignment: .leading)
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
