import SwiftUI

/// An inactive ship panel; app navigation remains available outside this view.
struct DisconnectedDeckView: View {
    @Environment(\.manufacturerTheme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "xmark")
                .font(.system(size: 48, weight: .ultraLight))
                .foregroundStyle(theme.palette.dim)
                .accessibilityHidden(true)
            Text("No ship connection")
                .mfdLabelStyle(theme, size: 22, display: true)
                .foregroundStyle(theme.palette.text)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.panel.opacity(0.35))
        .overlay {
            Rectangle()
                .strokeBorder(theme.palette.line, lineWidth: HUD.hairline)
        }
        .overlay {
            CornerBrackets(length: 18)
                .stroke(theme.palette.dim.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Deck / ship connection", traits: .fixedLayout(width: 1194, height: 834)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.applyShipContext(name: nil)
        return state
    }()
    VStack(spacing: 16) {
        HStack {
            Button("Simulate ClearDriver") {
                state.applyShipContext(name: nil)
            }
            Button("Simulate ship connection") {
                state.applyShipContext(name: "Drake Cutter Rambler")
            }
        }
        DeckView(state: state)
    }
    .padding(20)
    .background { ThemeBackdropView() }
    .manufacturerTheme(.drake)
}
