import SwiftUI

struct CreditRecorderView: View {
    let store: SessionActivityStore
    let horizontal: Bool
    @Environment(\.manufacturerTheme) private var manufacturerTheme
    @State private var selectedID: UUID?
    private var theme: MFDTheme { MFDTheme(manufacturerTheme) }
    private var record: RecordedSession? { store.sessions.first(where: { $0.id == selectedID }) ?? store.sessions.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Session finances").font(.largeTitle.bold()).foregroundStyle(theme.accent)
            Text("Rewards recorded while monitoring. Wallet balance and unrecorded spending are unknown.")
                .foregroundStyle(theme.muted)
            ActivitySessionControls(store: store, selectedID: $selectedID)
            if let record {
                MFDColumns(horizontal: horizontal) {
                    MFDPanel(theme: theme, highlighted: true) {
                        Text("Logged rewards").font(.headline)
                        Text("\(record.rewards["aUEC", default: 0].formatted()) aUEC")
                            .font(.system(size: 42, weight: .medium, design: .monospaced))
                            .minimumScaleFactor(0.5).lineLimit(1)
                            .accessibilityIdentifier("credits.sessionRewards")
                        if let uec = record.rewards["UEC"], uec > 0 {
                            Text("\(uec.formatted()) UEC").monospacedDigit()
                        }
                        Text("\(record.rewardCount) reward notifications")
                        Text("Currencies are counted separately. This is recorded income, not session profit.")
                            .font(.caption).foregroundStyle(theme.muted)
                    }
                } trailing: {
                    MFDPanel(theme: theme) {
                        Text("Spending and fines").font(.headline)
                        Text("Not tracked yet")
                        Text("Purchase, sale and rental requests are excluded until their amounts and completion can be verified.")
                            .foregroundStyle(theme.muted)
                        Text("Rewards are not assigned to contracts without a matching mission ID.")
                            .font(.caption).foregroundStyle(theme.muted)
                    }
                }
                MFDPanel(theme: theme) {
                    Text("Recent rewards").font(.headline)
                    let rewards = record.recentEvents.filter { $0.kind == "reward" }
                    if rewards.isEmpty {
                        Text("No reward notifications recorded in this session.").foregroundStyle(theme.muted)
                    }
                    ForEach(rewards) { event in
                        HStack {
                            Text(event.at, format: .dateTime.hour().minute().second())
                            Spacer()
                            Text(verbatim: "+\((event.amount ?? 0).formatted()) \(event.currency ?? "")")
                                .monospacedDigit().foregroundStyle(theme.accent)
                        }
                    }
                    Text("The recent list is limited to the latest 128 activity events. Session reward totals retain all received rewards.")
                        .font(.caption).foregroundStyle(theme.muted)
                }
            } else {
                Text("Connect to the PC server to begin recording live rewards.").foregroundStyle(theme.muted)
            }
        }
        .foregroundStyle(theme.text)
    }
}

#Preview("Live session finances") {
    CreditRecorderView(store: SessionActivityStore(fileURL: nil), horizontal: true)
        .padding().manufacturerTheme(.rsi)
}
