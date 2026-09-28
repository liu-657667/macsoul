import SwiftUI

struct CardContainer<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MacSoulTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: MacSoulTheme.cardRadius, style: .continuous))
    }
}
