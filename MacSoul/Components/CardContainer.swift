import SwiftUI

struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MacSoulTheme.Spacing.card) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(MacSoulTheme.Spacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacSoulTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MacSoulTheme.Radius.card, style: .continuous))
    }
}

/// Decorative vector placeholder. The adjacent mood text carries the state.
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
