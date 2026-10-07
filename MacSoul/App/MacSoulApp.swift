import SwiftUI

@main
struct MacSoulApp: App {
    @StateObject private var store = AppStore(codexQuota: CodexQuotaProvider.nativeLive())
    @NSApplicationDelegateAdaptor(QuotaTerminationDelegate.self) private var terminationDelegate
    @AppStorage("macsoul.language") private var language = MacSoulLanguage.english.rawValue

    private var selectedLanguage: MacSoulLanguage { MacSoulLanguage(rawValue: language) ?? .english }

    var body: some Scene {
        WindowGroup(id: "main") {
            AppShellView()
                .environmentObject(store)
                .onAppear { terminationDelegate.store = store }
                .macSoulAppearance()
                .environment(\.macSoulLanguage, selectedLanguage)
                .environment(\.locale, selectedLanguage.locale)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 760)

        MenuBarExtra("MacSoul", image: "MacSoulMenuTemplateDraft") {
            MenuBarContentView()
                .environmentObject(store)
                .onAppear { terminationDelegate.store = store }
                .macSoulAppearance()
                .environment(\.macSoulLanguage, selectedLanguage)
                .environment(\.locale, selectedLanguage.locale)
        }
        .menuBarExtraStyle(.window)
    }
}

// Await all collector/scan teardown, including the MacSoul-owned quota child.
// Views still never launch or poll providers.
@MainActor final class QuotaTerminationDelegate: NSObject, NSApplicationDelegate {
    weak var store: AppStore?
    private var terminating = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        guard !terminating else { return .terminateLater }
        terminating = true
        Task {
            await store.stopQuotaForTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
