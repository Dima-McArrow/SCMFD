import SwiftUI

/// Semantic key color, resolved against the active manufacturer palette.
nonisolated enum KeyTint: Sendable {
    case accent
    case green
    case amber
    case red
    case blue

    func color(in palette: ManufacturerTheme.Palette) -> Color {
        switch self {
        case .accent: palette.accent
        case .green: palette.green
        case .amber: palette.amber
        case .red: palette.red
        case .blue: palette.blue
        }
    }
}

/// HUD key skin shared by every control: translucent glass, hairline outline in the
/// manufacturer shape, corner brackets outside the key, and a light that rises from the
/// bottom edge when the key is pressed or lit.
struct MFDKeyChrome: ViewModifier {
    @Environment(\.manufacturerTheme) private var theme

    let tint: Color
    let isLit: Bool
    let isPressed: Bool
    var isEnabled = true
    var showsBrackets = true

    private var isActive: Bool { isLit || isPressed }

    func body(content: Content) -> some View {
        let key = theme.key
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    key.fillGradient
                        .opacity(theme.colorScheme == .dark ? 0.55 : 0.85)
                    LinearGradient(
                        colors: [tint.opacity(isPressed ? 0.28 : isLit ? 0.16 : 0), .clear],
                        startPoint: .bottom,
                        endPoint: .center
                    )
                }
            }
            .overlay(alignment: .top) {
                KeyTopAccentView(accent: key.topAccent, color: tint)
                    .opacity(isActive ? 1 : 0.5)
            }
            .overlay(alignment: .leading) {
                if key.edgeWidth > 0 {
                    tint.opacity(isLit ? 0.9 : 0.3)
                        .frame(width: key.edgeWidth)
                }
            }
            .clipShape(key.shape)
            .overlay {
                key.shape.strokeBorder(
                    isActive ? tint.opacity(0.85) : theme.palette.lineHighlight.opacity(0.55),
                    lineWidth: HUD.hairline
                )
            }
            .overlay {
                if showsBrackets {
                    // Brackets float just outside the key and close in when pressed.
                    CornerBrackets(length: 8, inset: isPressed ? 3 : -3)
                        .stroke(tint.opacity(isActive ? 1 : 0.4), lineWidth: 1)
                        .shadow(color: isActive ? tint.opacity(0.8) : .clear, radius: 3)
                }
            }
            .shadow(color: isLit ? tint.opacity(0.28) : .clear, radius: 12)
            .shadow(color: key.shadow?.color ?? .clear, radius: key.shadow?.radius ?? 0, y: key.shadow?.y ?? 0)
            .scaleEffect(isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(key.shape)
            // Touch-down is immediate; only the release eases back to rest.
            .animation(isPressed ? nil : .easeOut(duration: 0.12), value: isPressed)
            .animation(.easeOut(duration: 0.3), value: isLit)
    }
}

extension View {
    /// Tracks a raw finger-down / finger-up, unlike `Button`, which only reports the release.
    /// Needed because the game must receive the key press the moment the finger lands.
    /// Dragging off the key keeps it held until the finger lifts, like a physical button.
    func trackingPress(_ state: GestureState<Bool>, isEnabled: Bool = true) -> some View {
        gesture(
            DragGesture(minimumDistance: 0).updating(state) { _, isPressed, _ in isPressed = true },
            isEnabled: isEnabled
        )
    }

    /// Themed label text: manufacturer font, letter case and tracking.
    func mfdLabelStyle(_ theme: ManufacturerTheme, size: CGFloat, display: Bool = false) -> some View {
        let font = display ? theme.typography.display : theme.typography.body
        return self
            .font(font.font(size: size, weight: theme.typography.labelWeight))
            .tracking(theme.labelTracking(for: size))
    }

    /// Icon glow when the manufacturer uses one.
    func mfdIconGlow(_ theme: ManufacturerTheme, color: Color) -> some View {
        shadow(color: theme.icons.glowRadius > 0 ? color.opacity(0.6) : .clear, radius: theme.icons.glowRadius / 2)
    }
}

extension ManufacturerTheme {
    /// Localizes, then applies the manufacturer letter case.
    func label(_ resource: LocalizedStringResource) -> String {
        label(String(localized: resource))
    }
}
