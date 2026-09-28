import SwiftUI

struct CardContainer<Content: View>: View {
    @Environment(\.macSoulLanguage) private var language
    let title: String
    private let systemImage: String?
    private let assetImage: String?
    private let content: () -> Content

    init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.assetImage = nil
        self.content = content
    }

    init(title: String, assetImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = nil
        self.assetImage = assetImage
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.card) {
            Label {
                Text(language.text(title))
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                } else if let assetImage {
                    Image(assetImage)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                }
            }
                .font(.headline)
            content()
        }
        .padding(MacSoulTheme.Spacing.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacSoulTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MacSoulTheme.Radius.card, style: .continuous))
    }
}

/// The shared snapshot selects the artwork; adjacent text carries the accessible state.
struct SoulArtwork: View {
    let visual: SoulVisual?
    let size: CGFloat

    var body: some View {
        Group {
            if let visual {
                Image(visual.assetName)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            } else {
                SoulGlyph()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Explicit fallback for a snapshot whose Soul state is unavailable.
struct SoulGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary, lineWidth: 2)

            HStack(spacing: 18) {
                Circle().frame(width: 5, height: 5)
                Circle().frame(width: 5, height: 5)
            }
            .offset(y: -7)

            Path { path in
                path.move(to: CGPoint(x: 21, y: 39))
                path.addQuadCurve(to: CGPoint(x: 43, y: 39), control: CGPoint(x: 32, y: 45))
            }
            .stroke(.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: MacSoulTheme.Size.soulGlyph, height: MacSoulTheme.Size.soulGlyph)
        .accessibilityHidden(true)
    }
}
