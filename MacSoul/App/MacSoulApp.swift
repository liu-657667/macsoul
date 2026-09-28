import SwiftUI

@main
struct MacSoulApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            AppShellView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 620)
        }
        .defaultSize(width: 1120, height: 760)

        MenuBarExtra("MacSoul", systemImage: "brain.head.profile") {
            MenuBarContentView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
