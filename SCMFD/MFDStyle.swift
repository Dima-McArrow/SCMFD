import SwiftUI

struct MFDTheme {
    let accent: Color
    let background: Color
    let surface: Color
    let text: Color
    let muted: Color

    var edge: Color { accent.opacity(0.23) }
    var wash: Color { accent.opacity(0.08) }

    static let mission = MFDTheme(
        accent: Color(red: 0.37, green: 0.90, blue: 0.95),
        background: Color(red: 0.025, green: 0.065, blue: 0.085),
        surface: Color(red: 0.04, green: 0.10, blue: 0.13),
        text: Color(red: 0.85, green: 0.95, blue: 0.97),
        muted: Color(red: 0.53, green: 0.68, blue: 0.74)
    )
    static let credits = MFDTheme(
        accent: Color(red: 1.0, green: 0.73, blue: 0.32),
        background: Color(red: 0.075, green: 0.065, blue: 0.045),
        surface: Color(red: 0.12, green: 0.10, blue: 0.07),
        text: Color(red: 0.97, green: 0.91, blue: 0.81),
        muted: Color(red: 0.73, green: 0.66, blue: 0.53)
    )
    static let terminal = MFDTheme(
        accent: Color(red: 0.69, green: 0.92, blue: 0.54),
        background: Color(red: 0.035, green: 0.065, blue: 0.045),
        surface: Color(red: 0.06, green: 0.105, blue: 0.075),
        text: Color(red: 0.86, green: 0.94, blue: 0.82),
        muted: Color(red: 0.58, green: 0.71, blue: 0.57)
    )

    static func theme(for page: MFDPage) -> MFDTheme {
        switch page {
        case .mission: .mission
        case .credits: .credits
        case .terminal: .terminal
        }
    }
}

// Declared in an extension so the struct keeps its synthesized memberwise initializer.
extension MFDTheme {
    /// Legacy pages reuse the active manufacturer palette instead of their fixed per-page colors.
    init(_ manufacturer: ManufacturerTheme) {
        self.init(
            accent: manufacturer.palette.accent,
            background: manufacturer.palette.background,
            surface: manufacturer.palette.panel,
            text: manufacturer.palette.text,
            muted: manufacturer.palette.dim
        )
    }
}

struct MFDPanel<Content: View>: View {
    let theme: MFDTheme
    var highlighted = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(highlighted ? theme.wash : theme.surface)
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(theme.accent)
                .frame(width: 28, height: 2)
        }
        .overlay {
            CutCornerShape(cut: 12)
                .stroke(theme.edge, lineWidth: 1)
        }
        .clipShape(CutCornerShape(cut: 12))
    }
}

struct CutCornerShape: Shape {
    var cut: CGFloat

    func path(in rect: CGRect) -> Path {
        let corner = min(cut, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        path.closeSubpath()
        return path
    }
}

struct MFDLabel: View {
    let text: String
    let theme: MFDTheme

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .tracking(1.3)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct MFDTag: View {
    let text: String
    let theme: MFDTheme
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.medium))
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(filled ? theme.background : theme.accent)
            .background(filled ? theme.accent : theme.wash)
            .overlay { Rectangle().stroke(theme.edge, lineWidth: 1) }
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct MFDButtonStyle: ButtonStyle {
    let theme: MFDTheme
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .monospaced).weight(.medium))
            .frame(minHeight: 28)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(prominent ? theme.background : theme.accent)
            .background(prominent ? theme.accent : theme.wash)
            .overlay { Rectangle().stroke(theme.edge, lineWidth: 1) }
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.accent.opacity(0.4)).frame(height: 2)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(Rectangle())
    }
}

struct MFDReceipt: View {
    let title: String
    let message: String
    let theme: MFDTheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.alignleft")
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                MFDLabel(text: title, theme: theme)
                Text(message)
                    .font(.system(.callout, design: .monospaced))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(theme.wash)
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.accent).frame(width: 2)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MFDPageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let theme: MFDTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MFDLabel(text: eyebrow, theme: theme)
            Text(title)
                .font(.system(.largeTitle, design: .monospaced).weight(.medium))
                .foregroundStyle(theme.text)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MFDColumns<Leading: View, Trailing: View>: View {
    let horizontal: Bool
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        if horizontal {
            HStack(alignment: .top, spacing: 16) {
                leading.frame(maxWidth: .infinity)
                trailing.frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                leading
                trailing
            }
        }
    }
}

struct MFDSourceNote: View {
    let theme: MFDTheme
    let lines: [String]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                Link("Open the original Game.log sample ↗", destination: Self.sourceURL)
                    .font(.caption)
            }
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
        } label: {
            Text("Data source and limitations")
                .font(.system(.callout, design: .monospaced))
        }
        .tint(theme.accent)
        .padding(16)
        .background(theme.surface)
        .overlay { Rectangle().stroke(theme.edge, lineWidth: 1) }
    }

    private static let sourceURL = URL(
        string: "https://github.com/verdantnebula/sc-tracker/blob/main/fixtures/sample-events.log"
    )!
}

struct MFDGridBackground: View {
    let theme: MFDTheme

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0.0, through: size.width, by: 32) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: 32) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(theme.accent.opacity(0.035)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
