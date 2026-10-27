import SwiftUI

struct MissionControlView: View {
    let store: SessionActivityStore
    let horizontal: Bool
    @Environment(\.manufacturerTheme) private var manufacturerTheme
    @State private var selectedID: UUID?
    private var theme: MFDTheme { MFDTheme(manufacturerTheme) }
    private var record: RecordedSession? { store.sessions.first(where: { $0.id == selectedID }) ?? store.sessions.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Session contracts").font(.largeTitle.bold()).foregroundStyle(theme.accent)
            Text("Contracts and objectives observed in Game.log. The active contract list and objective progress may be incomplete.")
                .foregroundStyle(theme.muted)
            ActivitySessionControls(store: store, selectedID: $selectedID)
            if let record {
                if record.contracts.isEmpty {
                    MFDPanel(theme: theme) {
                        Text("No contract events recorded in this session.")
                        Text("Contracts already active when monitoring began may not appear.")
                            .font(.caption).foregroundStyle(theme.muted)
                    }
                }
                ForEach(record.contracts) { contract in
                    MFDPanel(theme: theme) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                if let title = contract.title, !title.isEmpty {
                                    Text(verbatim: title).font(.title3.bold())
                                } else {
                                    Text("Contract details unavailable").font(.title3.bold())
                                }
                                Text(verbatim: String(contract.id.uuidString.prefix(8)))
                                    .font(.caption.monospaced()).foregroundStyle(theme.muted)
                            }
                            Spacer()
                            Text(statusLabel(contract.status)).font(.caption.bold()).foregroundStyle(theme.accent)
                        }
                        ForEach(contract.objectives) { objective in
                            Label {
                                Text(verbatim: objective.text)
                            } icon: {
                                Image(systemName: objective.completed ? "checkmark.circle.fill" : "circle")
                            }
                            .foregroundStyle(objective.completed ? theme.accent : theme.text)
                        }
                        Text(contract.updatedAt, format: .dateTime.month().day().hour().minute().second())
                            .font(.caption).foregroundStyle(theme.muted)
                    }
                }
                Text("Required cargo and objective text are not a cargo hold reading. Rewards are listed separately in Finances.")
                    .font(.caption).foregroundStyle(theme.muted)
            } else {
                Text("Connect to the PC server to begin recording live contract events.").foregroundStyle(theme.muted)
            }
        }
        .foregroundStyle(theme.text)
    }

    private func statusLabel(_ status: String) -> LocalizedStringResource {
        switch status {
        case "accepted": "Accepted"
        case "contractComplete": "Completed"
        case "contractWithdrawn": "Withdrawn"
        case "contractFailed": "Failed"
        default: "Observed"
        }
    }
}

#Preview("Live session contracts") {
    MissionControlView(store: SessionActivityStore(fileURL: nil), horizontal: true)
        .padding().manufacturerTheme(.rsi)
}
