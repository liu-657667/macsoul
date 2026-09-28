import SwiftUI

enum MacSoulTheme {
    static let cardRadius: CGFloat = 18
    static let spacing: CGFloat = 16
    static let sidebarWidth: CGFloat = 200

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.86)
    }

    static var secondaryBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }
}
