import SwiftUI

/// Full emote board. Tapping a tile sends the random-variant command; the numbered chips
/// send a specific variant. Commands go out as chat lines through the command link.
struct EmotesView: View {
    @Environment(\.manufacturerTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(EmoteCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeader(category)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                            ForEach(category.groups) { group in
                                EmoteTile(group: group)
                            }
                        }
                    }
                }
            }
            // Room for the corner brackets that sit just outside each tile.
            .padding(6)
        }
        .scrollIndicators(.hidden)
    }

    private func sectionHeader(_ category: EmoteCategory) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Rectangle()
                .fill(theme.palette.accent)
                .frame(width: 2, height: 12)
            Text(theme.label(category.title))
                .mfdLabelStyle(theme, size: 13, display: true)
                .foregroundStyle(theme.palette.accent)
                .fixedSize()
            TickRuler(color: theme.palette.lineHighlight)
                .frame(maxWidth: .infinity)
            Text(verbatim: "\(category.groups.count)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.palette.dim)
        }
    }
}

/// Press state for HUD-skinned buttons that don't need raw key-down tracking.
struct MFDChromeButtonStyle: ButtonStyle {
    let tint: Color
    var isLit = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(MFDKeyChrome(tint: tint, isLit: isLit, isPressed: configuration.isPressed))
    }
}

private struct EmoteTile: View {
    @Environment(\.manufacturerTheme) private var theme
    @Environment(\.commandLink) private var link

    let group: EmoteGroup

    @State private var lastSent: String?
    @State private var sentCount = 0
    @State private var isFlashing = false
    /// Shown instead of the command when the server did not type it.
    @State private var failure: LocalizedStringResource?

    private let chipRowHeight: CGFloat = 22

    var body: some View {
        Button {
            send(group.command)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(theme.label(verbatim: group.title))
                    .mfdLabelStyle(theme, size: 13)
                    .foregroundStyle(theme.palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Group {
                    if let failure {
                        Text(theme.label(failure))
                            .foregroundStyle(theme.palette.red)
                    } else {
                        Text(verbatim: lastSent ?? group.command)
                            .foregroundStyle(isFlashing ? theme.palette.accent : theme.palette.dim)
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .contentTransition(.opacity)
                if group.variants > 0 {
                    // Reserves the space the variant chips are laid over.
                    Color.clear.frame(height: chipRowHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .buttonStyle(MFDChromeButtonStyle(tint: theme.palette.accent, isLit: isFlashing))
        .overlay(alignment: .bottomLeading) {
            if group.variants > 0 {
                variantChips
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: sentCount)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: group.title))
    }

    private var variantChips: some View {
        HStack(spacing: 5) {
            ForEach(1...group.variants, id: \.self) { variant in
                let command = group.command(variant: variant)
                let isLast = lastSent == command && isFlashing
                Button {
                    send(command)
                } label: {
                    Text(verbatim: "\(variant)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isLast ? theme.palette.background : theme.palette.dim)
                        .frame(maxWidth: 30, minHeight: chipRowHeight)
                        .background(isLast ? theme.palette.accent : .clear)
                        .overlay {
                            Rectangle().strokeBorder(theme.palette.dim.opacity(0.5), lineWidth: HUD.hairline)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: command))
            }
        }
    }

    private func send(_ command: String) {
        let ticket = link.send(chat: ChatEvent(text: command))
        Task {
            guard let label = await ticket.outcome.value.failureLabel else { return }
            withAnimation(.easeOut(duration: 0.2)) { failure = label }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.3)) { failure = nil }
        }
        sentCount += 1
        lastSent = command
        withAnimation(.easeOut(duration: 0.15)) { isFlashing = true }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.4)) { isFlashing = false }
        }
    }
}

#Preview("Emotes", traits: .fixedLayout(width: 1194, height: 834)) {
    EmotesView()
        .padding(20)
        .background { ThemeBackdropView() }
        .manufacturerTheme(.rsi)
}
