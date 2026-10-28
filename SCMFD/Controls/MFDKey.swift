import SwiftUI

/// Standard deck key. Sends key-down when the finger lands and key-up when it lifts.
/// For `.toggle` actions it also flips a lit ON/OFF state, but only once the server confirmed
/// the key-down; a rejected press shows its reason instead.
struct MFDKey: View {
    @Environment(\.manufacturerTheme) private var theme
    @Environment(\.commandLink) private var link

    let action: ShipAction
    @Binding var isLit: Bool
    var tint: KeyTint
    var title: LocalizedStringResource?
    var detail: Text?

    @GestureState private var isPressed = false
    @State private var inputPress = KeyPressTracker()
    @State private var pressCount = 0
    @State private var showsPressFeedback = false
    @State private var hold = TimedHoldController()
    /// Ticket of the current press, so the release can wait for its outcome.
    @State private var downTicket: CommandTicket?
    @State private var rejection: LocalizedStringResource?
    @State private var rejectionTask: Task<Void, Never>?

    init(_ action: ShipAction, isLit: Binding<Bool> = .constant(false), tint: KeyTint = .accent, title: LocalizedStringResource? = nil, detail: Text? = nil) {
        self.action = action
        self._isLit = isLit
        self.tint = tint
        self.title = title
        self.detail = detail
    }

    /// Neutral keys light up green; colored keys (weapons, shields...) keep their own color when lit.
    private var color: Color {
        isLit && tint == .accent ? theme.palette.green : tint.color(in: theme.palette)
    }

    private var isToggle: Bool { action.kind == .toggle }

    /// Hold duration when this key is a one-tap timed hold (e.g. SCM / NAV).
    private var holdSeconds: Double? {
        if case .hold(let seconds) = action.kind { seconds } else { nil }
    }

    private var holdPhase: String {
        if hold.isEngaged { return theme.label("Engaged") }
        if hold.isRunning { return theme.label("Engaging") }
        return theme.label("Ready")
    }

    private var status: String {
        theme.label(isLit ? "On" : "Off")
    }

    /// Reason the last press did nothing, from this key or its timed hold.
    private var failure: LocalizedStringResource? {
        rejection ?? hold.rejection
    }

    private func failureLine(_ failure: LocalizedStringResource) -> some View {
        HStack(spacing: 5) {
            StatusPip(color: theme.palette.red, isOn: true, size: 5)
            Text(theme.label(failure))
                .mfdLabelStyle(theme, size: 9)
                .foregroundStyle(theme.palette.red)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.top, 5)
        .transition(.opacity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: action.symbol)
                    .font(.system(size: 19, weight: theme.icons.weight))
                    .foregroundStyle(color)
                    .mfdIconGlow(theme, color: color)
                    .symbolEffect(.bounce, value: pressCount)
                Spacer(minLength: 8)
                KeycapLabel(chord: action.defaultChord)
            }

            Spacer(minLength: 6)

            Text(theme.label(title ?? action.title))
                .mfdLabelStyle(theme, size: 14)
                .foregroundStyle(theme.palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let detail {
                detail
                    .mfdLabelStyle(theme, size: 11)
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 5)
                    .contentTransition(.opacity)
            }

            if let failure {
                failureLine(failure)
            } else if isToggle {
                HStack(spacing: 5) {
                    StatusPip(color: color, isOn: isLit, size: 5)
                    Text(status)
                        .mfdLabelStyle(theme, size: 9)
                        .foregroundStyle(isLit ? color : theme.palette.dim)
                        .contentTransition(.opacity)
                }
                .padding(.top, 5)
            } else if holdSeconds != nil {
                HStack(spacing: 5) {
                    StatusPip(color: color, isOn: hold.isRunning || hold.isEngaged, size: 5)
                    Text(holdPhase)
                        .mfdLabelStyle(theme, size: 9)
                        .foregroundStyle(hold.isRunning || hold.isEngaged ? color : theme.palette.dim)
                        .contentTransition(.opacity)
                }
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottomLeading) {
            if holdSeconds != nil {
                // Thin progress rail along the bottom edge for compact timed holds.
                GeometryReader { geometry in
                    Rectangle()
                        .fill(hold.isEngaged ? theme.palette.green : color)
                        .frame(width: geometry.size.width * hold.progress, height: 1.5)
                        .shadow(color: (hold.isEngaged ? theme.palette.green : color).opacity(0.9), radius: 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .allowsHitTesting(false)
            }
        }
        .modifier(
            MFDKeyChrome(
                tint: color,
                isLit: isLit || hold.isRunning || hold.isEngaged,
                isPressed: isPressed || showsPressFeedback
            )
        )
        .trackingPress($isPressed, onChanged: {
            if inputPress.begin() { handlePress(true) }
        }, onEnded: {
            if inputPress.end() { handlePress(false) }
        })
        .onChange(of: isPressed) { _, pressed in
            if !pressed { cancelPress() }
        }
        .task(id: pressCount) {
            guard pressCount > 0 else { return }
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            showsPressFeedback = false
        }
        .onDisappear {
            showsPressFeedback = false
            hold.cancel(action, link: link)
            cancelPress()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pressCount)
        .sensoryFeedback(.success, trigger: hold.completions)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title ?? action.title))
        .accessibilityHint(detail ?? Text(""))
        .accessibilityValue(Text(isToggle ? status : action.defaultChord.description))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            handlePress(true)
            handlePress(false)
        }
    }

    private func cancelPress() {
        guard inputPress.end() else { return }
        // Cancelling a timed-hold touch must never activate the hold.
        if holdSeconds == nil { handlePress(false) }
    }

    private func handlePress(_ pressed: Bool) {
        // Keep quick taps visible without extending the actual key-down duration.
        if pressed {
            showsPressFeedback = true
        }
        if let holdSeconds {
            // One-tap timed hold: fire on release, the controller sends a single HOLD event.
            if pressed {
                pressCount += 1
                if !hold.isRunning { InterfaceAudio.shared.play(for: action) }
            } else {
                hold.toggle(action, seconds: holdSeconds, link: link)
            }
            return
        }
        if pressed {
            pressCount += 1
            InterfaceAudio.shared.play(for: action)
            downTicket = link.send(KeyEvent(action: action, phase: .down))
        } else {
            link.send(KeyEvent(action: action, phase: .up))
            guard let ticket = downTicket else { return }
            downTicket = nil
            Task { await settle(ticket) }
        }
    }

    /// The lit state follows the game input that was actually sent, not the finger.
    private func settle(_ ticket: CommandTicket) async {
        let outcome = await ticket.outcome.value
        if let failure = outcome.failureLabel {
            show(failure)
        } else if outcome == .sent, isToggle {
            withAnimation(.snappy) { isLit.toggle() }
        }
    }

    private func show(_ failure: LocalizedStringResource) {
        rejectionTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { rejection = failure }
        rejectionTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { rejection = nil }
        }
    }
}
