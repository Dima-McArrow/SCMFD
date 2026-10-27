import SwiftUI

/// Accent strip along the top edge of a key. It is a plain rectangle:
/// the key clips it with `MFDKeyShape`, so cut corners trim it like the CSS reference.
struct KeyTopAccentView: View {
    let accent: KeyTopAccent
    /// State color of the key, the CSS `currentColor`.
    let color: Color

    var body: some View {
        strip
            .frame(height: accent.height)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var strip: some View {
        switch accent.style {
        case .none:
            Color.clear
        case .fade(let end):
            LinearGradient(
                stops: [.init(color: color, location: 0), .init(color: color.opacity(0), location: end)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .solidFade(let endOpacity):
            LinearGradient(colors: [color, color.opacity(endOpacity)], startPoint: .leading, endPoint: .trailing)
        case .segment(let length, let trackOpacity):
            ZStack(alignment: .leading) {
                Color.white.opacity(trackOpacity)
                color.frame(width: length)
            }
        case .hazard(let stripeWidth, let dark):
            HazardStripes(stripeWidth: stripeWidth, color: color, dark: dark)
        case .centerFade:
            LinearGradient(
                stops: [
                    .init(color: color.opacity(0), location: 0.1),
                    .init(color: color, location: 0.5),
                    .init(color: color.opacity(0), location: 0.9),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

/// Diagonal accent/dark stripes, equivalent of `repeating-linear-gradient(-45deg, ...)`.
private struct HazardStripes: View {
    let stripeWidth: CGFloat
    let color: Color
    let dark: Color

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dark))

            // CSS measures stripe width across the stripe; along a horizontal edge it is √2 longer.
            let run = stripeWidth * CGFloat(2).squareRoot()
            var stripes = Path()
            var x = -size.height
            while x < size.width + size.height {
                stripes.move(to: CGPoint(x: x, y: 0))
                stripes.addLine(to: CGPoint(x: x + run, y: 0))
                stripes.addLine(to: CGPoint(x: x + run - size.height, y: size.height))
                stripes.addLine(to: CGPoint(x: x - size.height, y: size.height))
                stripes.closeSubpath()
                x += run * 2
            }
            context.fill(stripes, with: .color(color))
        }
    }
}

// MARK: - Preview

private struct KeyGeometrySample: View {
    @Environment(\.manufacturerTheme) private var theme

    var body: some View {
        let key = theme.key
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.manufacturer.shortName)
                .font(theme.typography.body.font(size: 12, weight: theme.typography.labelWeight))
                .tracking(theme.labelTracking(for: 12))
                .foregroundStyle(theme.palette.dim)

            ZStack {
                Text(theme.label("Landing gear"))
                    .font(theme.typography.display.font(size: 18, weight: .semibold))
                    .tracking(theme.labelTracking(for: 18))
                    .foregroundStyle(theme.palette.text)
            }
            .frame(width: 200, height: 96)
            .background(key.fillGradient)
            .overlay(alignment: .top) {
                KeyTopAccentView(accent: key.topAccent, color: theme.palette.accent)
            }
            .clipShape(key.shape)
            .overlay {
                key.shape.strokeBorder(theme.palette.line, lineWidth: 1)
            }
            .shadow(color: key.shadow?.color ?? .clear, radius: key.shadow?.radius ?? 0, y: key.shadow?.y ?? 0)
        }
        .padding(20)
        .background(theme.palette.background)
    }
}

#Preview("Key geometry / 5 manufacturers", traits: .fixedLayout(width: 1194, height: 300)) {
    HStack(spacing: 0) {
        ForEach(Manufacturer.allCases) { manufacturer in
            KeyGeometrySample()
                .manufacturerTheme(manufacturer.theme)
        }
    }
}
