import SwiftUI

/// Settings sheet: pick the SCMFD or a manufacturer skin and reset the button lights.
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.manufacturerTheme) private var theme

    @AppStorage(InterfaceAudio.enabledKey) private var soundsEnabled = true
    @AppStorage(InterfaceAudio.volumeKey) private var soundsVolume = 0.5

    @Binding var selection: AppTheme
    let onResetLights: () -> Void
    let isDeckDisconnected: Bool
    let onEnableDeck: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DeckRecoverySettings(isDisconnected: isDeckDisconnected) {
                        onEnableDeck()
                        dismiss()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Interface sounds", isOn: $soundsEnabled)
                            .onChange(of: soundsEnabled) { _, _ in
                                InterfaceAudio.shared.updateSettings()
                            }
                        Slider(value: $soundsVolume, in: 0...1) { editing in
                            if !editing { InterfaceAudio.shared.click() }
                        } label: {
                            Text("Sound volume")
                        }
                        .disabled(!soundsEnabled)
                        .onChange(of: soundsVolume) { _, _ in
                            InterfaceAudio.shared.updateSettings()
                        }
                        Button("Preview sound", systemImage: "speaker.wave.2") {
                            InterfaceAudio.shared.click()
                        }
                        .disabled(!soundsEnabled)
                    }
                    .foregroundStyle(theme.palette.text)

                    Text(theme.label(LocalizedStringResource("Theme")))
                        .mfdLabelStyle(theme, size: 13)
                        .foregroundStyle(theme.palette.dim)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                        ForEach(AppTheme.all) { appTheme in
                            Button {
                                withAnimation(.smooth(duration: 0.4)) { selection = appTheme }
                            } label: {
                                ThemeCard(theme: appTheme.theme, isSelected: appTheme == selection)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(verbatim: appTheme.theme.displayName))
                            .accessibilityAddTraits(appTheme == selection ? .isSelected : [])
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Button("Reset button lights", systemImage: "lightbulb.slash") {
                            onResetLights()
                        }
                        .buttonStyle(.bordered)
                        Text("Button lights follow your taps, not the game.")
                            .font(theme.typography.body.font(size: 13))
                            .foregroundStyle(theme.palette.dim)
                    }
                }
                .padding(24)
            }
            .background(theme.palette.background)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(theme.palette.accent)
    }
}

private struct DeckRecoverySettings: View {
    @Environment(\.manufacturerTheme) private var theme

    let isDisconnected: Bool
    let onEnable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Enable Deck manually", systemImage: "power", action: onEnable)
                .buttonStyle(.bordered)
                .disabled(!isDisconnected)
            Text(isDisconnected
                 ? "Back in the pilot seat? Enable the controls here. This does not power on your ship."
                 : "Deck is already enabled.")
                .font(theme.typography.body.font(size: 13))
                .foregroundStyle(theme.palette.dim)
        }
    }
}

/// Live preview of a skin: its own backdrop, key shape and fonts.
private struct ThemeCard: View {
    let theme: ManufacturerTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                ThemeBackdropView()
                Text(theme.label(ShipAction.quantumEngage.title))
                    .mfdLabelStyle(theme, size: 15, display: true)
                    .foregroundStyle(theme.palette.text)
                    .padding(.horizontal, 12)
                    .modifier(MFDKeyChrome(tint: theme.palette.accent, isLit: isSelected, isPressed: false))
                    .frame(height: 64)
                    .padding(.horizontal, 24)
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: theme.shortName)
                        .mfdLabelStyle(theme, size: 16, display: true)
                        .foregroundStyle(theme.palette.text)
                    Text(verbatim: theme.displayName)
                        .font(theme.typography.body.font(size: 12))
                        .foregroundStyle(theme.palette.dim)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? theme.palette.accent : theme.palette.line)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(12)
        .background(theme.palette.panel)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? theme.palette.accent : theme.palette.line, lineWidth: isSelected ? 2 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .manufacturerTheme(theme)
    }
}

#Preview("Settings / picker", traits: .fixedLayout(width: 834, height: 1000)) {
    @Previewable @State var selection = AppTheme.standard
    @Previewable @State var deck: DeckState = {
        let deck = DeckState()
        deck.apply(DeckUpdate(enabled: false, shipName: nil, resetLocalState: true))
        return deck
    }()
    ThemePickerView(
        selection: $selection,
        onResetLights: deck.resetLights,
        isDeckDisconnected: deck.isShipDisconnected,
        onEnableDeck: deck.enableManually
    )
        .manufacturerTheme(selection.theme)
}
