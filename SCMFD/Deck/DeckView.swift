import SwiftUI

/// Main control surface: two halves side by side in landscape, stacked in portrait.
struct DeckView: View {
    @Bindable var state: DeckState

    var body: some View {
        if state.isShipDisconnected {
            DisconnectedDeckView { state.enableManually() }
        } else {
            GeometryReader { geometry in
                let layout = geometry.size.width >= geometry.size.height
                    ? AnyLayout(HStackLayout(spacing: 16))
                    : AnyLayout(VStackLayout(spacing: 16))
                layout {
                    DeckHalf(pages: DeckPage.leftPages, state: state)
                    DeckHalf(pages: DeckPage.rightPages, state: state)
                }
            }
        }
    }
}

#Preview("Deck / landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        // The Deck starts off (FIX-07); show the keys.
        state.enableManually()
        return state
    }()
    DeckView(state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.drake)
}

#Preview("Deck / portrait", traits: .fixedLayout(width: 834, height: 1194)) {
    @Previewable @State var state: DeckState = {
        let state = DeckState()
        // The Deck starts off (FIX-07); show the keys.
        state.enableManually()
        return state
    }()
    DeckView(state: state)
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.aegis)
}
