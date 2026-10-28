import SwiftUI

struct PartyView: View {
    let store: PartyStore
    @Environment(\.manufacturerTheme) private var manufacturerTheme
    private var theme: MFDTheme { MFDTheme(manufacturerTheme) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Party").font(.largeTitle.bold()).foregroundStyle(theme.accent)
                    Text("Observed group only. Membership may be incomplete; names are not live online status.")
                        .foregroundStyle(theme.muted)
                    MFDPanel(theme: theme, highlighted: true) {
                        Text(statusLabel).font(.headline)
                        if store.isStale && store.receivedFeed {
                            Label("Observations may be stale", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(theme.muted)
                        }
                        if !store.receivedFeed {
                            Text("Waiting for Party observations from the PC. An updated server is required.")
                                .foregroundStyle(theme.muted)
                        }
                        if let at = store.state.lastObservedAt {
                            Text("Last Party observation").font(.caption).foregroundStyle(theme.muted)
                            Text(at, format: .dateTime.month().day().hour().minute().second())
                                .font(.caption.monospacedDigit())
                        }
                    }
                    MFDColumns(horizontal: geometry.size.width >= 800) {
                        MFDPanel(theme: theme) {
                            Text("Observed members").font(.headline)
                            Text("The list may be incomplete. No observed names does not mean an empty group.")
                                .font(.caption).foregroundStyle(theme.muted)
                            if store.state.members.isEmpty {
                                Text("No member names observed").foregroundStyle(theme.muted)
                            }
                            ForEach(store.state.members, id: \.self) { name in
                                HStack {
                                    Text(verbatim: name)
                                    if name == store.state.leader {
                                        Spacer()
                                        Text("Last known leader").font(.caption).foregroundStyle(theme.accent)
                                    }
                                }
                            }
                        }
                    } trailing: {
                        MFDPanel(theme: theme) {
                            Text("Last known leader").font(.headline)
                            if let leader = store.state.leader {
                                Text(verbatim: leader).font(.title3.bold())
                            } else {
                                Text("Leader unknown").foregroundStyle(theme.muted)
                            }
                            Text("Invitations and disappearing markers do not change this list.")
                                .font(.caption).foregroundStyle(theme.muted)
                        }
                    }
                    MFDPanel(theme: theme) {
                        Text("Party activity").font(.headline)
                        if store.state.history.isEmpty {
                            Text("No Party events observed in this capture.").foregroundStyle(theme.muted)
                        }
                        ForEach(store.state.history) { event in
                            HStack(alignment: .top, spacing: 16) {
                                Text(event.at, format: .dateTime.hour().minute().second())
                                    .font(.caption.monospacedDigit()).foregroundStyle(theme.muted)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(eventLabel(event.partyKind)).font(.subheadline.bold())
                                    if !event.text.isEmpty { Text(verbatim: event.text) }
                                }
                            }
                        }
                        Text("Latest 128 Party events in this capture. History is cleared when observation restarts.")
                            .font(.caption).foregroundStyle(theme.muted)
                    }
                }
                .frame(maxWidth: 1160)
                .frame(maxWidth: .infinity)
                .foregroundStyle(theme.text)
            }
        }
    }

    private var statusLabel: LocalizedStringResource {
        switch store.state.membership {
        case .unknown: "Party membership unknown"
        case .observed: "Party membership observed"
        case .disbanded: "Party disbanding observed"
        }
    }

    private func eventLabel(_ kind: PartyEventKind?) -> LocalizedStringResource {
        switch kind {
        case .created: "You created a party"
        case .joined: "You joined a party"
        case .memberJoined: "Member joined"
        case .memberLeft: "Member left"
        case .leaderChanged: "Leader changed"
        case .disbanded: "Party disbanded"
        case nil: "Observed"
        }
    }
}

#Preview("Observed Party") {
    PartyView(store: PartyStore()).padding().manufacturerTheme(.rsi)
}
