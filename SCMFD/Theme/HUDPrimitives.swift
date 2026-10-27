import SwiftUI

/// Hairline width used across the HUD: one physical pixel on Retina is too faint on glass,
/// so the HUD settles on 0.75pt.
nonisolated enum HUD {
    static let hairline: CGFloat = 0.75
}

// MARK: - Corner brackets

/// Four L-shaped corner marks, the signature framing of in-game MFD panels.
nonisolated struct CornerBrackets: Shape {
    /// Length of each bracket arm.
    var length: CGFloat = 10
    /// Distance from the frame edge; animating it makes the brackets close in on press.
    var inset: CGFloat = 0

    var animatableData: CGFloat {
        get { inset }
        set { inset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let frame = rect.insetBy(dx: inset, dy: inset)
        let arm = min(length, frame.width / 2, frame.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: frame.minX, y: frame.minY + arm))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.minX + arm, y: frame.minY))

        path.move(to: CGPoint(x: frame.maxX - arm, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + arm))

        path.move(to: CGPoint(x: frame.maxX, y: frame.maxY - arm))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.maxX - arm, y: frame.maxY))

        path.move(to: CGPoint(x: frame.minX + arm, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - arm))
        return path
    }
}

// MARK: - Tick ruler

/// Horizontal ruler of fine ticks with a taller tick every `majorEvery` steps.
struct TickRuler: View {
    var color: Color
    var spacing: CGFloat = 6
    var majorEvery = 5

    var body: some View {
        Canvas { context, size in
            var minor = Path()
            var major = Path()
            var index = 0
            var x: CGFloat = 0
            while x <= size.width {
                if index % majorEvery == 0 {
                    major.move(to: CGPoint(x: x, y: 0))
                    major.addLine(to: CGPoint(x: x, y: size.height))
                } else {
                    minor.move(to: CGPoint(x: x, y: size.height * 0.45))
                    minor.addLine(to: CGPoint(x: x, y: size.height))
                }
                x += spacing
                index += 1
            }
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: size.height))
            baseline.addLine(to: CGPoint(x: size.width, y: size.height))

            context.stroke(minor, with: .color(color.opacity(0.35)), lineWidth: HUD.hairline)
            context.stroke(major, with: .color(color.opacity(0.7)), lineWidth: HUD.hairline)
            context.stroke(baseline, with: .color(color.opacity(0.35)), lineWidth: HUD.hairline)
        }
        .frame(height: 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Status pip

/// Small diamond indicator: hollow when off, filled and glowing when on.
struct StatusPip: View {
    var color: Color
    var isOn: Bool
    var size: CGFloat = 6

    var body: some View {
        Rectangle()
            .fill(isOn ? color : .clear)
            .overlay { Rectangle().strokeBorder(color.opacity(isOn ? 1 : 0.6), lineWidth: HUD.hairline) }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
            .shadow(color: isOn ? color.opacity(0.9) : .clear, radius: 4)
            .frame(width: size * 1.5, height: size * 1.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Keycap

/// Bound keyboard chord in a hairline box, e.g. `ALT+N`.
struct KeycapLabel: View {
    @Environment(\.manufacturerTheme) private var theme
    let chord: KeyChord

    var body: some View {
        Text(verbatim: chord.description.uppercased())
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(theme.palette.dim)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay { Rectangle().strokeBorder(theme.palette.dim.opacity(0.5), lineWidth: HUD.hairline) }
            .accessibilityHidden(true)
    }
}

#Preview("HUD primitives", traits: .fixedLayout(width: 500, height: 260)) {
    VStack(alignment: .leading, spacing: 24) {
        TickRuler(color: ManufacturerTheme.rsi.palette.accent)
        HStack(spacing: 24) {
            StatusPip(color: .green, isOn: true)
            StatusPip(color: .green, isOn: false)
            KeycapLabel(chord: KeyChord("n", .alt))
        }
        CornerBrackets(length: 12)
            .stroke(ManufacturerTheme.rsi.palette.accent, lineWidth: 1)
            .frame(width: 200, height: 80)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ManufacturerTheme.rsi.palette.background)
    .manufacturerTheme(.rsi)
}
