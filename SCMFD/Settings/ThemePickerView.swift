import SwiftUI

/// Settings sheet: interface sounds, Auto theme and the SCMFD or a manufacturer skin.
/// Reset Deck lives in the top bar (FIX-07).
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.manufacturerTheme) private var theme

    @AppStorage(InterfaceAudio.enabledKey) private var soundsEnabled = true
    @AppStorage(InterfaceAudio.volumeKey) private var soundsVolume = 0.5
    @AppStorage(AppTheme.autoThemeKey) private var autoTheme = true

    @Binding var selection: AppTheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
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

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Auto theme", isOn: $autoTheme)
                            .foregroundStyle(theme.palette.text)
                        Text("Switches to the ship's manufacturer when you join its channel and back to SCMFD when you leave the ship. A manual pick stays until the next change.")
                            .font(theme.typography.body.font(size: 13))
                            .foregroundStyle(theme.palette.dim)
                    }

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
    ThemePickerView(selection: $selection)
        .manufacturerTheme(selection.theme)
}
