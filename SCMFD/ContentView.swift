import SwiftUI

/// Top-level screens: the control deck plus the legacy Game.log info pages.
nonisolated enum AppScreen: Hashable, Identifiable, Sendable {
    case deck
    case emotes
    case debug
    case info(MFDPage)

    static let all: [AppScreen] = {
        var screens: [AppScreen] = [.deck, .emotes, .info(.mission), .info(.credits)]
        #if DEBUG
        screens.append(.debug)
        #endif
        return screens
    }()

    var id: String {
        switch self {
        case .deck: "deck"
        case .emotes: "emotes"
        case .debug: "debug"
        case .info(let page): page.rawValue
        }
    }
}

struct ContentView: View {
    /// The key predates the SCMFD theme; a stored manufacturer raw value still decodes (see `AppTheme`).
    @AppStorage("manufacturer") private var appTheme: AppTheme = .standard
    @AppStorage(AppTheme.autoThemeKey) private var autoTheme = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var screen: AppScreen = .deck
    @State private var deck: DeckState
    @State private var session = DemoSession()
    @State private var activity: SessionActivityStore
    @State private var showsSettings = false
    @State private var showsConnect = false
    /// One server connection for the whole app; the Debug tab shows the same one.
    @State private var server: ServerConnection
    @State private var networkLink: NetworkCommandLink

    private static let consoleLink = ConsoleCommandLink()

    init() {
        let server = ServerConnection()
        let activity = SessionActivityStore()
        let deck = DeckState()
        server.onActivity = { page in activity.receive(page) }
        server.onState = { state, connectionId in deck.receive(state, connectionId: connectionId) }
        _activity = State(initialValue: activity)
        _deck = State(initialValue: deck)
        _server = State(initialValue: server)
        _networkLink = State(initialValue: NetworkCommandLink(connection: server))
    }

    private var theme: ManufacturerTheme { appTheme.theme }

    /// Paired: every key goes to the server, and nothing is sent while the link is down.
    /// Not paired: the console stub keeps the deck usable for UI work.
    private var commandLink: any CommandLink {
        server.pairedServer == nil ? Self.consoleLink : networkLink
    }

    var body: some View {
        ZStack {
            ThemeBackdropView()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                topBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
        }
        .foregroundStyle(theme.palette.text)
        .tint(theme.palette.accent)
        .manufacturerTheme(theme)
        .environment(\.commandLink, commandLink)
        .animation(.smooth(duration: 0.45), value: appTheme)
        .task { connectIfPaired() }
        .onChange(of: server.phase) { _, phase in
            if case .ready = phase {
                activity.setConnected(true)
            } else {
                activity.setConnected(false)
                deck.connectionLost()
            }
        }
        // Only a join switches the theme; ClearDriver, reconnects and manual Deck enable never do (FIX-04).
        // Writing the picker's own storage means a manual pick wins until the next join.
        .onChange(of: deck.lastShipJoin) { _, join in
            guard let join else { return }
            appTheme = AppTheme.afterJoin(join, current: appTheme, autoTheme: autoTheme)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            // The server releases every held key when the connection closes.
            case .background: server.disconnect()
            case .active: connectIfPaired()
            default: break
            }
        }
        .sheet(isPresented: $showsConnect) {
            ConnectToPCView(connection: server)
                .manufacturerTheme(theme)
        }
        .sheet(isPresented: $showsSettings) {
            ThemePickerView(
                selection: $appTheme,
                onResetLights: deck.resetLights,
                isDeckDisconnected: deck.isShipDisconnected,
                onEnableDeck: {
                    deck.enableManually()
                    screen = .deck
                }
            )
                .manufacturerTheme(theme)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .deck:
            DeckView(state: deck)
                .transition(.opacity)
        case .emotes:
            EmotesView()
                .transition(.opacity)
        case .debug:
            ConnectionDebugView(server: server)
                .transition(.opacity)
        case .info(let page):
            GeometryReader { geometry in
                ScrollView {
                    infoPage(page, horizontal: geometry.size.width >= 800)
                        .frame(maxWidth: 1160)
                        .frame(maxWidth: .infinity)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func infoPage(_ page: MFDPage, horizontal: Bool) -> some View {
        switch page {
        case .mission: MissionControlView(store: activity, horizontal: horizontal)
        case .credits: CreditRecorderView(store: activity, horizontal: horizontal)
        case .terminal: CommandTerminalView(session: session, horizontal: horizontal)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    brand
                    Spacer(minLength: 8)
                    screenSwitcher
                    Spacer(minLength: 8)
                    linkStatus
                    settingsButton
                }
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        brand
                        Spacer(minLength: 8)
                        linkStatus
                        settingsButton
                    }
                    screenSwitcher
                }
            }
            TickRuler(color: theme.palette.lineHighlight, spacing: 8, majorEvery: 10)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(theme.palette.accent)
                .frame(width: 2, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: theme.shortName)
                    .mfdLabelStyle(theme, size: 18, display: true)
                    .foregroundStyle(theme.palette.accent)
                    .contentTransition(.opacity)
                Text(verbatim: theme.displayName.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(theme.palette.dim)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var screenSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(AppScreen.all) { item in
                Button {
                    withAnimation(.smooth(duration: 0.3)) { screen = item }
                } label: {
                    VStack(spacing: 7) {
                        Text(screenTitle(item))
                            .mfdLabelStyle(theme, size: 16)
                            .lineLimit(1)
                            .foregroundStyle(item == screen ? theme.palette.text : theme.palette.dim)
                        Rectangle()
                            .fill(item == screen ? theme.palette.accent : .clear)
                            .frame(height: 1.5)
                            .shadow(color: item == screen ? theme.palette.accent.opacity(0.8) : .clear, radius: 3)
                    }
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .frame(minWidth: 44, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == screen ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: screen)
    }

    private func screenTitle(_ item: AppScreen) -> String {
        switch item {
        case .deck: theme.label("Deck")
        case .emotes: theme.label("Emotes")
        case .debug: theme.label("Debug")
        case .info(let page): theme.label(page.shortTitle)
        }
    }

    /// Tapping the status opens Connect to PC.
    private var linkStatus: some View {
        let (title, color) = linkState
        return Button {
            showsConnect = true
        } label: {
            HStack(spacing: 6) {
                StatusPip(color: color, isOn: true, size: 5)
                Text(theme.label(title))
                    .mfdLabelStyle(theme, size: 9)
                    .foregroundStyle(theme.palette.dim)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens Connect to PC"))
    }

    private var linkState: (LocalizedStringResource, Color) {
        guard server.pairedServer != nil else { return ("Console link", theme.palette.amber) }
        switch server.phase {
        case .ready: return ("Server link", theme.palette.green)
        case .awaitingWelcome, .pairing, .pairingRequired: return ("Connecting", theme.palette.amber)
        case .idle, .closed: return ("No link", theme.palette.red)
        }
    }

    private func connectIfPaired() {
        guard server.pairedServer != nil else { return }
        switch server.phase {
        case .idle, .closed: server.connect()
        case .awaitingWelcome, .pairingRequired, .pairing, .ready: break
        }
    }

    private var settingsButton: some View {
        Button {
            showsSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: theme.icons.weight))
                .foregroundStyle(theme.palette.accent)
                .frame(width: 38, height: 38)
                .overlay {
                    CornerBrackets(length: 7)
                        .stroke(theme.palette.accent.opacity(0.7), lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Settings"))
    }
}

#Preview("SCMFD / App", traits: .fixedLayout(width: 1194, height: 834)) {
    ContentView()
}
