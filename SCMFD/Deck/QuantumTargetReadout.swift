import SwiftUI

/// HUD readout of the current quantum target: a starmap destination, free mode,
/// or no data while the Game.log feed is not connected.
struct QuantumTargetReadout: View {
    @Environment(\.manufacturerTheme) private var theme

    let target: QuantumTarget

    private var color: Color {
        switch target {
        case .unknown: theme.palette.dim
        case .freeMode: theme.palette.amber
        case .destination: theme.palette.accent
        }
    }

    private var value: String {
        switch target {
        case .unknown: theme.label("Waiting for Game.log")
        case .freeMode: theme.label("Free mode")
        case .destination(let name): name
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 2)
                .shadow(color: color.opacity(0.8), radius: 3)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    StatusPip(color: color, isOn: target != .unknown, size: 5)
                    Text(theme.label("QT target"))
                        .mfdLabelStyle(theme, size: 9)
                        .foregroundStyle(theme.palette.dim)
                }
                Text(verbatim: value)
                    .mfdLabelStyle(theme, size: target == .unknown ? 13 : 17, display: true)
                    .foregroundStyle(target == .unknown ? theme.palette.dim : color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 8)

            Image(systemName: "scope")
                .font(.system(size: 18, weight: theme.icons.weight))
                .foregroundStyle(color.opacity(target == .unknown ? 0.4 : 1))
                .mfdIconGlow(theme, color: color)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 14)
        .frame(height: 64)
        .background(theme.palette.panel.opacity(theme.colorScheme == .dark ? 0.45 : 0.7))
        .overlay { Rectangle().strokeBorder(theme.palette.line, lineWidth: HUD.hairline) }
        .animation(.easeOut(duration: 0.3), value: target)
        .accessibilityElement(children: .combine)
    }
}

#Preview("QT target / states", traits: .fixedLayout(width: 560, height: 280)) {
    VStack(spacing: 14) {
        QuantumTargetReadout(target: .unknown)
        QuantumTargetReadout(target: .freeMode)
        QuantumTargetReadout(target: .destination("ARC-L1 Wide Forest Station"))
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { ThemeBackdropView() }
    .manufacturerTheme(.rsi)
}
