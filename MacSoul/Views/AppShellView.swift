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
    }
}
