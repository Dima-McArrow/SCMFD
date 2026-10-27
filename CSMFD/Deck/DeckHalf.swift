import SwiftUI

/// One half of the deck: a ruled heading, the current page's keys and a page switcher,
/// framed as a bracketed glass panel.
struct DeckHalf: View {
    @Environment(\.manufacturerTheme) private var theme

    let pages: [DeckPage]
    @Bindable var state: DeckState

    @State private var selection: DeckPage?
    @Namespace private var tabNamespace

    private var current: DeckPage { selection ?? pages[0] }
    private var currentIndex: Int { pages.firstIndex(of: current) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            DeckPageContent(page: current, state: state)
                .id(current)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    )
                )
                .frame(maxHeight: .infinity)

            tabBar
        }
        .padding(18)
        .background(theme.palette.panel.opacity(theme.colorScheme == .dark ? 0.35 : 0.55))
        .overlay { Rectangle().strokeBorder(theme.palette.line.opacity(0.9), lineWidth: HUD.hairline) }
        .overlay {
            CornerBrackets(length: 14)
                .stroke(theme.palette.accent.opacity(0.75), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Rectangle()
                .fill(theme.palette.accent)
                .frame(width: 2, height: 12)
            Text(theme.label(current.title))
                .mfdLabelStyle(theme, size: 13, display: true)
                .foregroundStyle(theme.palette.accent)
                .contentTransition(.opacity)
                .fixedSize()
            TickRuler(color: theme.palette.lineHighlight)
                .frame(maxWidth: .infinity)
            Text(verbatim: "\(currentIndex + 1)/\(pages.count)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.palette.dim)
                .contentTransition(.numericText())
        }
    }

    private var tabBar: some View {
        HStack(spacing: 10) {
            ForEach(pages) { page in
                Button {
                    withAnimation(.smooth(duration: 0.3)) { selection = page }
                } label: {
                    VStack(spacing: 8) {
                        Text(theme.label(page.title))
                            .mfdLabelStyle(theme, size: 16)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(page == current ? theme.palette.text : theme.palette.dim)
                        ZStack {
                            Rectangle()
                                .fill(theme.palette.line)
                                .frame(height: HUD.hairline)
                            if page == current {
                                Rectangle()
                                    .fill(theme.palette.accent)
                                    .frame(height: 1.5)
                                    .shadow(color: theme.palette.accent.opacity(0.8), radius: 3)
                                    .matchedGeometryEffect(id: "tab", in: tabNamespace)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(minWidth: 44, maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == current ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: current)
    }
}
