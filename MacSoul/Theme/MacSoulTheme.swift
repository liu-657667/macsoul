import SwiftUI

enum MacSoulTheme {
    enum Spacing {
        static let compact: CGFloat = 4
        static let tight: CGFloat = 8
        static let regular: CGFloat = 12
        static let card: CGFloat = 16
        static let section: CGFloat = 24
    }

    enum Radius {
        static let tile: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum Size {
        static let soulGlyph: CGFloat = 64
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.86)
    }

    static var secondaryBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }
}
