import SwiftUI

@main
struct MacSoulApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("macsoul.language") private var language = MacSoulLanguage.english.rawValue

    private var selectedLanguage: MacSoulLanguage { MacSoulLanguage(rawValue: language) ?? .english }

    var body: some Scene {
        WindowGroup(id: "main") {
            AppShellView()
                .environmentObject(store)
                .macSoulAppearance()
                .environment(\.macSoulLanguage, selectedLanguage)
                .environment(\.locale, selectedLanguage.locale)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 760)

        MenuBarExtra("MacSoul", image: "MacSoulMenuTemplateDraft") {
            MenuBarContentView()
                .environmentObject(store)
                .macSoulAppearance()
                .environment(\.macSoulLanguage, selectedLanguage)
                .environment(\.locale, selectedLanguage.locale)
        }
        .menuBarExtraStyle(.window)
    }
}
