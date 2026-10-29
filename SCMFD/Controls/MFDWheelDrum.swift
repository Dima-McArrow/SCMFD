import SwiftUI

/// Deck control for a mouse-wheel axis: drag the tick window up to increase, down to decrease,
/// or tap - / + for exactly one step. It shows no value; every step goes to `onStep`.
/// The ticks follow the finger and stop when it lifts: no inertia, no snap, no auto-repeat.
struct MFDWheelDrum: View {
    @Environment(\.manufacturerTheme) private var theme

    let title: LocalizedStringResource
    /// Binding shown in the keycap box, e.g. "ALT+WHEEL". Display only, never sent as a chord.
    let keycap: String
    var failure: LocalizedStringResource? = nil
    let onStep: (RelativeWheelStepper.Intention) -> Void

    /// Drag distance per step, also the tick spacing: one step moves the drum by exactly one tick.
    private static let stepDistance: CGFloat = 18

    @State private var stepper = RelativeWheelStepper(distancePerStep: Double(MFDWheelDrum.stepDistance))
    /// Unbounded tick offset in points; the canvas wraps it.
    @State private var tickOffset: CGFloat = 0
    /// Tick offset when the current drag began; nil when no drag is running.
    @State private var dragStartOffset: CGFloat?
    @State private var dragSteps = 0
    @State private var buttonSteps = 0
    @GestureState private var isTouching = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(theme.label(title))
                        .mfdLabelStyle(theme, size: 14)
                        .foregroundStyle(theme.palette.text)
                        // Always two lines tall, so side-by-side drums keep aligned windows when only one title wraps.
                        .lineLimit(2, reservesSpace: true)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 5) {
                        StatusPip(color: theme.palette.red, isOn: failure != nil, size: 5)
                        Text(failure.map { theme.label($0) } ?? "")
                            .mfdLabelStyle(theme, size: 9)
                            .foregroundStyle(theme.palette.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    // Reserve the caption's space so failures do not move the drum under the finger.
                    .opacity(failure == nil ? 0 : 1)
                    .accessibilityHidden(failure == nil)
                }
                Spacer(minLength: 8)
                WheelKeycap(text: keycap)
            }

            // + above and - below the window, matching the drag direction (up increases).
            stepButton("plus", intention: .increase)
            tickWindow
            stepButton("minus", intention: .decrease)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .modifier(MFDKeyChrome(tint: theme.palette.accent, isLit: false, isPressed: dragStartOffset != nil))
        .sensoryFeedback(.selection, trigger: dragSteps)
        .sensoryFeedback(.impact(weight: .light), trigger: buttonSteps)
        // A cancelled drag never reaches onEnded; the gesture state resetting is the reliable signal.
        .onChange(of: isTouching) { _, touching in
            if !touching { endDrag() }
        }
        .onDisappear { endDrag() }
        // The title and caption are read as they are; the tick window itself is the adjustable element.
        .accessibilityElement(children: .contain)
    }

    /// Vertical counterpart of `TickRuler`: same hairline, opacities and short minor ticks, scrolled by the finger.
    private var tickWindow: some View {
        DrumTicks(offset: tickOffset, spacing: Self.stepDistance)
        // Fade toward the edges so the strip reads as a drum.
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.25),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay { Rectangle().strokeBorder(theme.palette.line, lineWidth: HUD.hairline) }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isTouching) { _, touching, _ in touching = true }
                .onChanged { value in
                    if dragStartOffset == nil {
                        dragStartOffset = tickOffset
                        stepper?.begin()
                    }
                    let translation = value.translation.height
                    tickOffset = (dragStartOffset ?? tickOffset) + translation
                    if let intention = stepper?.update(translation: Double(translation)) {
                        dragSteps += 1
                        onStep(intention)
                    }
                }
                .onEnded { _ in endDrag() }
        )
        .accessibilityElement()
        .accessibilityLabel(Text(title))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: tapStep(.increase)
            case .decrement: tapStep(.decrease)
            @unknown default: break
            }
        }
    }

    private func stepButton(_ symbol: String, intention: RelativeWheelStepper.Intention) -> some View {
        Button {
            tapStep(intention)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: theme.icons.weight))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(DrumStepButtonStyle())
        // The adjustable tick window already gives VoiceOver the same single steps.
        .accessibilityHidden(true)
    }

    /// One discrete step from - / + or VoiceOver: the drum glides by one tick, as if dragged.
    private func tapStep(_ intention: RelativeWheelStepper.Intention) {
        InterfaceAudio.shared.click()
        buttonSteps += 1
        withAnimation(.snappy(duration: 0.18)) {
            tickOffset += intention == .increase ? -Self.stepDistance : Self.stepDistance
        }
        onStep(intention)
    }

    private func endDrag() {
        stepper?.reset()
        dragStartOffset = nil
    }
}

/// The drum's ticks. Animatable, so a - / + step glides instead of jumping; a Canvas alone would not interpolate.
private struct DrumTicks: View, Animatable {
    @Environment(\.manufacturerTheme) private var theme

    var offset: CGFloat
    let spacing: CGFloat
    private let majorEvery = 5

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard spacing > 0, offset.isFinite else { return }
            // Wrapping by the major period keeps indices small and the long ticks in place.
            let phase = offset.truncatingRemainder(dividingBy: spacing * CGFloat(majorEvery))
            let mid = size.height / 2
            var minor = Path()
            var major = Path()
            var index = Int(((-mid - phase) / spacing).rounded(.up))
            var y = mid + phase + CGFloat(index) * spacing
            while y <= size.height {
                let isMajor = index.isMultiple(of: majorEvery)
                let length = size.width * (isMajor ? 0.7 : 0.7 * 0.55)
                let start = CGPoint(x: (size.width - length) / 2, y: y)
                let end = CGPoint(x: (size.width + length) / 2, y: y)
                if isMajor {
                    major.move(to: start)
                    major.addLine(to: end)
                } else {
                    minor.move(to: start)
                    minor.addLine(to: end)
                }
                index += 1
                y += spacing
            }
            let color = theme.palette.lineHighlight
            context.stroke(minor, with: .color(color.opacity(0.35)), lineWidth: HUD.hairline)
            context.stroke(major, with: .color(color.opacity(0.7)), lineWidth: HUD.hairline)

            // Fixed index marks at the center, so the eye has a reference while the ticks move.
            var marks = Path()
            marks.move(to: CGPoint(x: 0, y: mid))
            marks.addLine(to: CGPoint(x: 8, y: mid))
            marks.move(to: CGPoint(x: size.width - 8, y: mid))
            marks.addLine(to: CGPoint(x: size.width, y: mid))
            context.stroke(marks, with: .color(theme.palette.accent), lineWidth: 1.5)
        }
    }
}

/// Small - / + key: hairline outline in the manufacturer shape, lit while pressed.
private struct DrumStepButtonStyle: ButtonStyle {
    @Environment(\.manufacturerTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let color = theme.palette.accent
        configuration.label
            .foregroundStyle(color)
            .mfdIconGlow(theme, color: color)
            .background(color.opacity(configuration.isPressed ? 0.22 : 0))
            .clipShape(theme.key.shape)
            .overlay {
                theme.key.shape.strokeBorder(
                    configuration.isPressed ? color.opacity(0.85) : theme.palette.lineHighlight.opacity(0.55),
                    lineWidth: HUD.hairline
                )
            }
    }
}

/// Same look as `KeycapLabel`, but for a verbatim binding text that is not a server `KeyChord`.
private struct WheelKeycap: View {
    @Environment(\.manufacturerTheme) private var theme
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(theme.palette.dim)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay { Rectangle().strokeBorder(theme.palette.dim.opacity(0.5), lineWidth: HUD.hairline) }
            .accessibilityHidden(true)
    }
}
