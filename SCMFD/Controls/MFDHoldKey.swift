import SwiftUI

/// Key for actions the game performs on a long press (quantum, auto land, exit seat, self-destruct).
/// One tap sends a timed hold; the tick ring fills for exactly the hold duration.
/// Tapping again while it runs cancels the hold.
struct MFDHoldKey: View {
    @Environment(\.manufacturerTheme) private var theme
    @Environment(\.commandLink) private var link

    let action: ShipAction
    var tint: KeyTint = .accent
    var isEnabled = true
    var caption: LocalizedStringResource = "Tap to engage"

    @GestureState private var isPressed = false
    @State private var inputPress = KeyPressTracker()
    @State private var hold = TimedHoldController()

    private var seconds: Double {
        if case .hold(let seconds) = action.kind { seconds } else { 1 }
    }

    private var color: Color { tint.color(in: theme.palette) }

    private var phaseColor: Color {
        if hold.rejection != nil { return theme.palette.red }
        return hold.isRunning || hold.isEngaged ? color : theme.palette.dim
    }

    private var phase: String {
        if let rejection = hold.rejection { return theme.label(rejection) }
        if hold.isEngaged { return theme.label("Engaged") }
        if hold.isRunning { return theme.label("Engaging") }
        return theme.label(isEnabled ? "Ready" : "Locked")
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if geometry.size.height < 170 {
                    compactLayout(height: geometry.size.height)
                } else {
                    fullLayout(size: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .modifier(
            MFDKeyChrome(
                tint: color,
                isLit: hold.isEngaged || hold.isRunning,
                isPressed: isPressed,
                isEnabled: isEnabled
            )
        )
        .trackingPress($isPressed, isEnabled: isEnabled, onChanged: {
            guard isEnabled, inputPress.begin() else { return }
            if !hold.isRunning { InterfaceAudio.shared.play(for: action) }
        }, onEnded: {
            guard inputPress.end(), isEnabled else { return }
            hold.toggle(action, seconds: seconds, link: link)
        })
        .onChange(of: isPressed) { _, pressed in
            if !pressed { _ = inputPress.end() }
        }
        .onChange(of: isEnabled) { _, enabled in
            if !enabled {
                _ = inputPress.end()
                hold.cancel(action, link: link)
            }
        }
        .onDisappear {
            _ = inputPress.end()
            hold.cancel(action, link: link)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hold.isRunning) { _, running in running }
        .sensoryFeedback(.success, trigger: hold.completions)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(action.title))
        .accessibilityValue(Text(phase))
        .accessibilityHint(Text(caption))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            guard isEnabled else { return }
            if !hold.isRunning { InterfaceAudio.shared.play(for: action) }
            hold.toggle(action, seconds: seconds, link: link)
        }
    }

    // MARK: - Layouts

    private func ring(iconSize: CGFloat) -> some View {
        TickRing(
            progress: hold.progress,
            color: hold.isEngaged ? theme.palette.green : color,
            track: theme.palette.lineHighlight.opacity(0.6),
            isSpinning: hold.isRunning
        ) {
            Image(systemName: action.symbol)
                .font(.system(size: iconSize, weight: theme.icons.weight))
                .foregroundStyle(color)
                .mfdIconGlow(theme, color: color)
                .symbolEffect(.pulse, isActive: hold.isRunning)
        }
    }

    private var phaseLine: some View {
        HStack(spacing: 6) {
            StatusPip(color: hold.rejection == nil ? color : theme.palette.red,
                      isOn: hold.isEngaged || hold.isRunning || hold.rejection != nil, size: 5)
            Text(phase)
                .mfdLabelStyle(theme, size: 10)
                .foregroundStyle(phaseColor)
                .contentTransition(.opacity)
        }
    }

    private func compactLayout(height: CGFloat) -> some View {
        HStack(spacing: 16) {
            ring(iconSize: 16)
                // GeometryReader can report a near-zero height in early layout passes; never go negative.
                .frame(width: max(0, min(height - 28, 64)))
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.label(action.title))
                    .mfdLabelStyle(theme, size: 15)
                    .foregroundStyle(theme.palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                phaseLine
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                KeycapLabel(chord: action.defaultChord)
                Text(theme.label(caption))
                    .mfdLabelStyle(theme, size: 9)
                    .foregroundStyle(theme.palette.dim)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
    }

    private func fullLayout(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(theme.label(action.title))
                    .mfdLabelStyle(theme, size: 18, display: true)
                    .foregroundStyle(theme.palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 8)
                KeycapLabel(chord: action.defaultChord)
            }
            Spacer(minLength: 10)
            ring(iconSize: 26)
                .frame(maxWidth: min(size.width * 0.45, size.height - 110, 160))
            Spacer(minLength: 10)
            HStack {
                phaseLine
                Spacer(minLength: 8)
                Text(theme.label(caption))
                    .mfdLabelStyle(theme, size: 9)
                    .foregroundStyle(theme.palette.dim)
                    .lineLimit(1)
            }
        }
        .padding(16)
    }
}
