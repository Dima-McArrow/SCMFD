import SwiftUI

enum MFDPreviewScenario {
    case standard
    case abandoned
    case withFine
    case withReceipts
}

struct MFDPreviewSurface: View {
    let page: MFDPage
    @State private var session: DemoSession
    @State private var activity = SessionActivityStore(fileURL: nil)

    init(page: MFDPage, scenario: MFDPreviewScenario = .standard) {
        self.page = page
        let session = DemoSession()
        switch scenario {
        case .standard:
            break
        case .abandoned:
            session.replayAbandonment()
        case .withFine:
            session.toggleFine()
        case .withReceipts:
            session.sendDemoCommand(.requestLanding)
            session.sendDemoCommand(.toggleGear)
        }
        _session = State(initialValue: session)
    }

    var body: some View {
        GeometryReader { geometry in
            let theme = MFDTheme.theme(for: page)
            ZStack {
                theme.background.ignoresSafeArea()
                MFDGridBackground(theme: theme).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        MFDTag(text: "DEMO / ARCHIVE 19 JUN 2026", theme: theme)
                        switch page {
                        case .mission:
                            MissionControlView(store: activity, horizontal: geometry.size.width >= 800)
                        case .credits:
                            CreditRecorderView(store: activity, horizontal: geometry.size.width >= 800)
                        case .terminal:
                            CommandTerminalView(session: session, horizontal: geometry.size.width >= 800)
                        }
                    }
                    .padding(geometry.size.width >= 600 ? 32 : 16)
                    .frame(maxWidth: 1160)
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(theme.text)
            .tint(theme.accent)
        }
        .preferredColorScheme(.dark)
    }
}
