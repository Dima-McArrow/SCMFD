import SwiftUI

/// Full-screen manufacturer backdrop: base tone, off-screen glow and a texture pattern.
/// Does not ignore safe areas by itself; the caller decides (usually `.ignoresSafeArea()`).
struct ThemeBackdropView: View {
    @Environment(\.manufacturerTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Canvas { [theme] context, size in
                BackdropPainter.drawBase(theme, in: &context, size: size)
                BackdropPainter.drawGlow(theme.backdrop, in: &context, size: size)
                BackdropPainter.drawPattern(theme.backdrop.pattern, in: &context, size: size)
            }
            if case .stars = theme.backdrop.pattern {
                StarfieldLayer(animated: !reduceMotion)
            }
            Canvas { [theme] context, size in
                BackdropPainter.drawVignette(theme, in: &context, size: size)
            }
            ScanBandLayer(color: theme.palette.accent, animated: !reduceMotion)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Static layers

nonisolated private enum BackdropPainter {
    /// Texture lines are white at very low opacity, matching the CSS reference.
    private static let texture = Color.white

    static func drawBase(_ theme: ManufacturerTheme, in context: inout GraphicsContext, size: CGSize) {
        let rect = Path(CGRect(origin: .zero, size: size))
        if let bottom = theme.backdrop.baseBottom {
            context.fill(
                rect,
                with: .linearGradient(
                    Gradient(colors: [theme.palette.background, bottom]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        } else {
            context.fill(rect, with: .color(theme.palette.background))
        }
    }

    /// CSS `radial-gradient(ellipse W% H% at X% Y%, color, transparent 60%)`.
    /// A circular gradient is drawn in a horizontally scaled space to get the ellipse.
    static func drawGlow(_ backdrop: ThemeBackdrop, in context: inout GraphicsContext, size: CGSize) {
        let radiusX = size.width * backdrop.glowRadii.width
        let radiusY = size.height * backdrop.glowRadii.height
        guard radiusX > 0, radiusY > 0 else { return }

        var layer = context
        layer.translateBy(x: size.width * backdrop.glowCenter.x, y: size.height * backdrop.glowCenter.y)
        layer.scaleBy(x: radiusX / radiusY, y: 1)

        let fadeRadius = radiusY * 0.62
        let diameter = fadeRadius * 2
        let circle = Path(ellipseIn: CGRect(x: -fadeRadius, y: -fadeRadius, width: diameter, height: diameter))
        layer.fill(
            circle,
            with: .radialGradient(
                Gradient(colors: [backdrop.glowColor, backdrop.glowColor.opacity(0)]),
                center: .zero,
                startRadius: 0,
                endRadius: fadeRadius
            )
        )
    }

    /// Darkens the edges so the eye settles on the deck; light themes get a softer edge.
    static func drawVignette(_ theme: ManufacturerTheme, in context: inout GraphicsContext, size: CGSize) {
        let edge = theme.colorScheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.08)
        let radius = max(size.width, size.height) * 0.75
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(stops: [.init(color: .clear, location: 0.55), .init(color: edge, location: 1)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    static func drawPattern(_ pattern: ThemeBackdrop.Pattern, in context: inout GraphicsContext, size: CGSize) {
        switch pattern {
        case .none, .stars:
            // Stars live in their own animated layer.
            return
        case .grid(let spacing):
            var path = Path()
            for x in stride(from: 0, through: size.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(texture.opacity(0.028)), lineWidth: 1)

            // Fine crosshairs on every fourth intersection, like a targeting grid.
            var crosses = Path()
            let arm: CGFloat = 3
            for x in stride(from: 0, through: size.width, by: spacing * 4) {
                for y in stride(from: 0, through: size.height, by: spacing * 4) {
                    crosses.move(to: CGPoint(x: x - arm, y: y))
                    crosses.addLine(to: CGPoint(x: x + arm, y: y))
                    crosses.move(to: CGPoint(x: x, y: y - arm))
                    crosses.addLine(to: CGPoint(x: x, y: y + arm))
                }
            }
            context.stroke(crosses, with: .color(texture.opacity(0.12)), lineWidth: HUD.hairline)
        case .scanlines:
            // repeating-linear-gradient(0deg, line 0 2px, transparent 2px 5px)
            var path = Path()
            for y in stride(from: 0, through: size.height, by: 5) {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: 2))
            }
            context.fill(path, with: .color(texture.opacity(0.018)))
        case .diagonalHatch(let spacing):
            // repeating-linear-gradient(45deg, line 0 1px, transparent 1px <spacing>):
            // the period is measured across the lines, so along the x axis it is √2 longer.
            let step = spacing * CGFloat(2).squareRoot()
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                x += step
            }
            context.stroke(path, with: .color(texture.opacity(0.015)), lineWidth: 1)
        }
    }
}

// MARK: - Scan band

/// A soft horizontal band that sweeps down the screen once every few seconds,
/// the only ambient motion on the deck.
private struct ScanBandLayer: View {
    let color: Color
    let animated: Bool

    private let period: TimeInterval = 9

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                Canvas { context, size in
                    let phase = timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: period) / period
                    let bandHeight = size.height * 0.18
                    let y = -bandHeight + (size.height + bandHeight * 2) * phase
                    let rect = CGRect(x: 0, y: y, width: size.width, height: bandHeight)
                    context.fill(
                        Path(rect),
                        with: .linearGradient(
                            Gradient(colors: [color.opacity(0), color.opacity(0.045), color.opacity(0)]),
                            startPoint: CGPoint(x: 0, y: rect.minY),
                            endPoint: CGPoint(x: 0, y: rect.maxY)
                        )
                    )
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: rect.midY))
                    line.addLine(to: CGPoint(x: size.width, y: rect.midY))
                    context.stroke(line, with: .color(color.opacity(0.08)), lineWidth: HUD.hairline)
                }
            }
        }
    }
}

// MARK: - Starfield

/// Twinkling stars. Redraws at a low frame rate: the effect is slow, so 20 fps is enough
/// and keeps the iPad cool during long sessions.
private struct StarfieldLayer: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animated)) { timeline in
            let time = animated ? timeline.date.timeIntervalSinceReferenceDate : nil
            Canvas { context, size in
                Starfield.draw(in: &context, size: size, time: time)
            }
        }
    }
}

nonisolated private enum Starfield {
    struct Star {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let opacity: Double
        let phase: Double
        let speed: Double
    }

    /// Positions are normalized, so the sky keeps its layout on rotation and resize.
    /// A fixed seed makes it identical between launches and previews.
    static let stars: [Star] = {
        var generator = SplitMix64(seed: 0x5C_3FD)
        return (0..<160).map { _ in
            Star(
                x: .random(in: 0...1, using: &generator),
                y: .random(in: 0...1, using: &generator),
                radius: .random(in: 0.4...1.1, using: &generator),
                opacity: .random(in: 0.25...0.75, using: &generator),
                phase: .random(in: 0...(2 * .pi), using: &generator),
                speed: .random(in: 0.4...1.6, using: &generator)
            )
        }
    }()

    static func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval?) {
        for star in stars {
            var opacity = star.opacity
            if let time {
                opacity *= 0.6 + 0.4 * sin(time * star.speed + star.phase)
            }
            let center = CGPoint(x: star.x * size.width, y: star.y * size.height)
            let rect = CGRect(
                x: center.x - star.radius,
                y: center.y - star.radius,
                width: star.radius * 2,
                height: star.radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
        }
    }
}

/// Small deterministic PRNG (SplitMix64) for reproducible star layouts.
nonisolated private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

// MARK: - Preview

#Preview("Backdrops / 5 manufacturers", traits: .fixedLayout(width: 1194, height: 834)) {
    HStack(spacing: 1) {
        ForEach(Manufacturer.allCases) { manufacturer in
            let theme = manufacturer.theme
            ZStack(alignment: .topLeading) {
                ThemeBackdropView()
                Text(manufacturer.shortName)
                    .font(theme.typography.display.font(size: 22, weight: .semibold))
                    .tracking(theme.labelTracking(for: 22))
                    .foregroundStyle(theme.palette.text)
                    .padding(20)
            }
            .manufacturerTheme(theme)
        }
    }
    .background(.black)
}
