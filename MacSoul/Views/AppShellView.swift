import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case system = "System"
    case network = "Network"
    case ai = "AI Coding"
    case dev = "Dev"
    case cleaner = "Cleaner"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .system: "gauge.with.dots.needle.50percent"
        case .network: "network"
        case .ai: "sparkles"
        case .dev: "terminal"
        case .cleaner: "CleanerBroom"
        case .settings: "gearshape"
        }
    }
}

struct AppShellView: View {
    @State private var selection: AppSection? = .overview
    @State private var windowID = UUID()
    @EnvironmentObject private var store: AppStore
    @Environment(\.macSoulLanguage) private var language

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { item in
                Label {
                    Text(language.text(item.rawValue))
                } icon: {
                    if item == .cleaner {
                        Image(item.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: item.icon)
                    }
                }
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            Group {
                switch selection ?? .overview {
                case .overview: OverviewView()
                case .system: SystemView()
                case .network: NetworkView()
                case .ai: AICodingView()
                case .dev: DevView()
                case .cleaner: CleanerView()
                case .settings: SettingsView()
                }
            }
        }
        .background(MainWindowPresence(id: windowID, section: selection ?? .overview, store: store))
        .onChange(of: selection) { store.setWindowSection(windowID, section: $0 ?? .overview) }
    }
}

// Observe only the actual WindowGroup window. MenuBarExtra never registers here.
private struct MainWindowPresence: NSViewRepresentable {
    let id: UUID
    let section: AppSection
    let store: AppStore

    static func visible(isVisible: Bool, minimized: Bool, appHidden: Bool) -> Bool {
        isVisible && !minimized && !appHidden
    }
    func makeCoordinator() -> Coordinator { Coordinator(id: id, store: store) }
    func makeNSView(context: Context) -> PresenceView {
        let view = PresenceView()
        view.windowChanged = { [weak coordinator = context.coordinator] window in coordinator?.attach(window) }
        return view
    }
    func updateNSView(_ view: PresenceView, context: Context) {
        context.coordinator.section = section
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak view] in
            coordinator?.attach(view?.window)
        }
    }
    static func dismantleNSView(_ view: PresenceView, coordinator: Coordinator) {
        view.windowChanged = nil
        coordinator.detach()
    }
    final class PresenceView: NSView {
        var windowChanged: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.windowChanged?(self?.window) }
        }
    }
    @MainActor final class Coordinator {
        private let id: UUID
        private weak var store: AppStore?
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        var section: AppSection = .overview
        init(id: UUID, store: AppStore) { self.id = id; self.store = store }
        deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
        func attach(_ value: NSWindow?) {
            if window !== value {
                detach()
                window = value
                if let value {
                    for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                                 NSWindow.didDeminiaturizeNotification, NSApplication.didHideNotification,
                                 NSApplication.didUnhideNotification] {
                        observers.append(NotificationCenter.default.addObserver(forName: name, object: name == NSApplication.didHideNotification || name == NSApplication.didUnhideNotification ? nil : value, queue: .main) { [weak self] _ in
                            Task { @MainActor in self?.publish() }
                        })
                    }
                    observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: value, queue: .main) { [weak self] _ in
                        Task { @MainActor in self?.detach() }
                    })
                }
            }
            publish()
        }
        func detach() {
            observers.forEach { NotificationCenter.default.removeObserver($0) }; observers = []
            store?.setWindow(id, visible: false, section: section); window = nil
        }
        private func publish() {
            let visible = window.map { MainWindowPresence.visible(isVisible: $0.isVisible, minimized: $0.isMiniaturized, appHidden: NSApp.isHidden) } ?? false
            store?.setWindow(id, visible: visible, section: section)
        }
    }
}
