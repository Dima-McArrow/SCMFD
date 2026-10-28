import SwiftUI

/// An inactive ship panel; app navigation remains available outside this view.
struct DisconnectedDeckView: View {
    @Environment(\.manufacturerTheme) private var theme

    /// Enable Deck: one tap, sends nothing to the game (FIX-07).
    let onEnable: () -> Void

    var body: some View {
        VStack(spacing: 24) {
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
            .accessibilityElement(children: .combine)

            Button(action: onEnable) {
                // An explicit resource: a plain literal would pick the unlocalized `label(String)` overload.
                Label(theme.label(LocalizedStringResource("Enable Deck")), systemImage: "power")
                    .mfdLabelStyle(theme, size: 15)
                    .foregroundStyle(theme.palette.accent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 48)
                    .overlay {
                        CornerBrackets(length: 9)
                            .stroke(theme.palette.accent.opacity(0.7), lineWidth: 1)
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
    }
}

#Preview("Deck / ship connection", traits: .fixedLayout(width: 1194, height: 834)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        state.apply(DeckUpdate(enabled: false, shipName: nil, resetKeys: false))
        return state
    }()
    VStack(spacing: 16) {
        HStack {
            Button("Simulate channel left") {
                state.apply(DeckUpdate(enabled: false, shipName: nil, resetKeys: false))
            }
            Button("Simulate ship connection") {
                state.apply(DeckUpdate(enabled: true, shipName: "Drake Cutter Rambler", resetKeys: false))
            }
        }
        DeckView(state: state)
    }
    .padding(20)
    .background { ThemeBackdropView() }
    .manufacturerTheme(.drake)
}
