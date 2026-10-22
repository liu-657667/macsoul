import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language
    @StateObject private var loginItem = LaunchAgentController(manager: LaunchAgentManager.native())
    @AppStorage("macsoul.appearance") private var appearance = MacSoulAppearance.system.rawValue
    @AppStorage("macsoul.language") private var selectedLanguage = MacSoulLanguage.english.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.section) {
                TypographySection(language.text("Current build capabilities")) {
                    Grid(alignment: .leading, horizontalSpacing: MacSoulTheme.Spacing.card, verticalSpacing: MacSoulTheme.Spacing.regular) {
                        TypographyField(language.text("Data mode"), value: language.text(store.systemMode == .live ? "Live · availability per source" : "Bundled Mock"))
                        TypographyField(language.text("Live system sampling"), value: language.text(store.systemMode == .live ? "CPU, memory, disk, battery, processes" : "Not connected"))
                        TypographyField(language.text("Live developer environment"), value: language.text(store.systemMode == .live ? "Runtimes and TCP listeners" : "Not connected"))
                        TypographyField(language.text("Live network monitoring"), value: language.text(store.systemMode == .live ? "Path, public IP, proxy, tunnel hints, connectivity" : "Not connected"))
                        TypographyField(language.text("Live quota providers"), value: language.text(store.systemMode == .live ? "Availability per provider" : "Not connected"))
                        TypographyField(language.text("Cleaner"), value: language.cleanerText(store.systemMode == .live ? "Read only · on demand" : "Preview uses Mock fixtures; no filesystem scan runs."))
                        TypographyField(language.text("Cleaner deletion"), value: language.text("Not available"))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                TypographySection(language.text("System data source")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        Picker(language.text("Mode"), selection: Binding(
                            get: { store.systemMode },
                            set: { store.setSystemMode($0) }
                        )) {
                            ForEach(SystemMode.allCases) { option in
                                Text(language.text(option.label)).tag(option)
                            }
                        }
                        .font(MacSoulTheme.Typography.fieldLabel)
                        .frame(maxWidth: 440, alignment: .leading)
                        Text(language.text("Live mode includes System, Dev Environment and Network. AI availability is reported per provider."))
                            .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                TypographySection(language.text("Network external requests")) {
                    HStack(alignment: .top, spacing: MacSoulTheme.Spacing.card) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                            Text(language.text("Connectivity probes"))
                                .font(MacSoulTheme.Typography.fieldLabel)
                            Text(language.text("In Live mode, probes send anonymous HTTPS HEAD requests to GitHub, OpenAI and Anthropic. No account credentials or project data are sent. Turning probes off cancels pending probes."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                            Text(language.text("Live mode queries IPinfo for public IPv4/IPv6, with ident.me as fallback. Developer Preview sends no external network requests."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Toggle(language.text("Connectivity probes"), isOn: Binding(
                            get: { store.connectivityEnabled }, set: { store.setConnectivityEnabled($0) }))
                            .labelsHidden()
                            .font(MacSoulTheme.Typography.fieldLabel)
                            .toggleStyle(.switch)
                            .accessibilityLabel(language.text("Connectivity probes"))
                            .accessibilityHint(language.text("Turning probes off cancels pending connectivity probes."))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                TypographySection(language == .english ? "Launch at Login" : "登录时启动") {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        Toggle(language == .english ? "Launch MacSoul at login" : "登录时启动 MacSoul", isOn: Binding(
                            get: { loginItem.state.isConfigured }, set: { enabled in Task { await loginItem.setEnabled(enabled) } }))
                            .font(MacSoulTheme.Typography.fieldLabel)
                            .toggleStyle(.switch)
                            .disabled(loginItem.isBusy || !loginItem.state.permitsChanges)
                            .accessibilityValue(loginItem.state.label(language))
                            .accessibilityHint(loginItem.state.explanation(language))
                        Text(loginItem.state.label(language)).font(MacSoulTheme.Typography.status)
                        Text(loginItem.state.explanation(language))
                            .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                        if let error = loginItem.operationError {
                            Text(error.message(language))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.orange)
                        }
                        Text(language == .english ? "Uses a user LaunchAgent. Changes apply only when you use this switch; login launch still needs separate verification."
                             : "使用用户级 LaunchAgent；仅操作此开关时更改配置，实际登录启动仍需另行验证。")
                            .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                        Button(language.text("Refresh")) { Task { await loginItem.refresh() } }.controlSize(.small)
                            .disabled(loginItem.isBusy)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                TypographySection(language.text("App appearance")) {
                    VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                        Picker(language.text("Appearance"), selection: $appearance) {
                            ForEach(MacSoulAppearance.allCases) { option in
                                Text(language.text(option.label)).tag(option.rawValue)
                            }
                        }
                        .font(MacSoulTheme.Typography.fieldLabel)
                        .frame(maxWidth: 440, alignment: .leading)
                        Text(language.text("Changes MacSoul windows only; the macOS appearance stays as it is."))
                            .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                TypographySection(language == .english ? "Language" : "语言") {
                    Picker(language == .english ? "Language" : "语言", selection: $selectedLanguage) {
                        ForEach(MacSoulLanguage.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .font(MacSoulTheme.Typography.fieldLabel)
                    .frame(maxWidth: 440, alignment: .leading)
                }
                #if DEBUG
                if store.systemMode == .preview, let currentFixture = store.previewFixture {
                    TypographySection(language.text("Developer preview scenarios")) {
                        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.tight) {
                            Picker(language.text("Fixture"), selection: Binding(
                                get: { store.previewFixture ?? currentFixture },
                                set: { store.selectPreviewFixture($0) }
                            )) {
                                ForEach(MockProvider.Fixture.allCases) { fixture in
                                    Text(language.text(fixture.label)).tag(fixture)
                                }
                            }
                            .font(MacSoulTheme.Typography.fieldLabel)
                            .frame(maxWidth: 440, alignment: .leading)
                            Text(language.text("The fixture selector changes local demo data. It does not enable live collection or account access."))
                                .font(MacSoulTheme.Typography.supporting).lineSpacing(2).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                TypographySection(language.text("Menu Bar artwork · DRAFT")) {
                    HStack(spacing: MacSoulTheme.Spacing.regular) {
                        Image("MacSoulMenuTemplateDraft")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .accessibilityHidden(true)
                        Text(language.text("18 pt template candidate is active; small-size artwork remains DRAFT."))
                            .font(MacSoulTheme.Typography.body)
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
        .task { await loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in Task { await loginItem.refresh() } }
    }
}
