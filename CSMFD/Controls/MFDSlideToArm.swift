import SwiftUI

/// Safety latch for dangerous actions: slide the thumb to the end to arm for a few seconds.
/// It never sends keys itself; it only enables the control it guards.
struct MFDSlideToArm: View {
    @Environment(\.manufacturerTheme) private var theme

    @Binding var isArmed: Bool
    var armedSeconds: Double = 6

    @State private var offset: CGFloat = 0
    @State private var disarmTask: Task<Void, Never>?

    private let thumbWidth: CGFloat = 72
    private let height: CGFloat = 56

    var body: some View {
        GeometryReader { geometry in
            let travel = max(geometry.size.width - thumbWidth - 8, 1)
            let color = theme.palette.red
            ZStack(alignment: .leading) {
                track(color: color)

                Text(theme.label(isArmed ? "Armed" : "Slide to arm"))
                    .mfdLabelStyle(theme, size: 11)
                    .foregroundStyle(isArmed ? color : theme.palette.dim)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)

                thumb(color: color)
                    .offset(x: 4 + (isArmed ? travel : offset))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isArmed else { return }
                                offset = min(max(0, value.translation.width), travel)
                            }
                            .onEnded { _ in
                                if offset > travel * 0.9 {
                                    arm()
                                } else {
                                    withAnimation(.spring(duration: 0.35, bounce: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: height)
        .sensoryFeedback(.warning, trigger: isArmed) { _, armed in armed }
        .onChange(of: isArmed) { _, armed in
            if !armed { withAnimation(.spring(duration: 0.35)) { offset = 0 } }
        }
        .onDisappear { disarmTask?.cancel() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isArmed ? "Armed" : "Slide to arm"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { arm() }
    }

    private func track(color: Color) -> some View {
        ZStack {
            theme.palette.panel.opacity(0.5)
            if isArmed {
                KeyTopAccentView(
                    accent: KeyTopAccent(style: .hazard(stripeWidth: 6, dark: .clear), height: height),
                    color: color.opacity(0.12)
                )
            }
            // Chevron ticks pointing the way to slide.
            HStack(spacing: 10) {
                ForEach(0..<12, id: \.self) { _ in
                    Image(systemName: "chevron.compact.right")
                        .font(.system(size: 12, weight: .ultraLight))
                }
            }
            .foregroundStyle(theme.palette.dim.opacity(isArmed ? 0 : 0.35))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 14)
        }
        .clipShape(theme.key.shape)
        .overlay {
            theme.key.shape.strokeBorder(color.opacity(isArmed ? 0.9 : 0.4), lineWidth: HUD.hairline)
        }
        .overlay {
            CornerBrackets(length: 8, inset: -3)
                .stroke(color.opacity(isArmed ? 1 : 0.4), lineWidth: 1)
        }
    }

    private func thumb(color: Color) -> some View {
        MFDKeyShape(corners: theme.key.corners)
            .fill(color.opacity(isArmed ? 0.45 : 0.2))
            .overlay {
                MFDKeyShape(corners: theme.key.corners)
                    .strokeBorder(color, lineWidth: 1)
            }
            .overlay {
                Image(systemName: isArmed ? "lock.open" : "chevron.right.2")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(color)
                    .contentTransition(.symbolEffect(.replace))
            }
            .shadow(color: color.opacity(isArmed ? 0.7 : 0.3), radius: isArmed ? 10 : 4)
            .frame(width: thumbWidth, height: height - 8)
    }

    private func arm() {
        withAnimation(.spring(duration: 0.3)) { isArmed = true }
        disarmTask?.cancel()
        disarmTask = Task {
            try? await Task.sleep(for: .seconds(armedSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35)) { isArmed = false }
        }
    }
}
