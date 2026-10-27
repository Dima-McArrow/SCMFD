import SwiftUI

struct ActivitySessionControls: View {
    let store: SessionActivityStore
    @Binding var selectedID: UUID?
    @Environment(\.manufacturerTheme) private var manufacturerTheme

    private var selected: RecordedSession? { store.sessions.first(where: { $0.id == selectedID }) ?? store.sessions.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.sessions.isEmpty {
                Picker("Tracking session", selection: Binding(
                    get: { selectedID ?? store.sessions.first?.id },
                    set: { selectedID = $0 }
                )) {
                    ForEach(store.sessions) { session in
                        Text(session.startedAt, format: .dateTime.year().month().day().hour().minute().second())
                            .tag(Optional(session.id))
                    }
                }
                .pickerStyle(.menu)
                Button("Start new tracking session") {
                    store.startNewSession()
                    selectedID = store.sessions.first?.id
                }
                .buttonStyle(MFDButtonStyle(theme: MFDTheme(manufacturerTheme)))
                .disabled(!store.isConnected || !store.isCaughtUp || store.sessions.first?.ended != false)
                if selected?.ended == true {
                    Text("Saved session").font(.caption)
                } else {
                    Text("Monitoring session").font(.caption)
                }
            }
            if !store.receivedLiveFeed {
                Text("Waiting for the server activity feed. Saved history remains available.")
                    .font(.caption).foregroundStyle(manufacturerTheme.palette.amber)
            } else if !store.isConnected {
                Text("Disconnected. Showing saved session data.")
                    .font(.caption).foregroundStyle(manufacturerTheme.palette.amber)
            } else if !store.isCaughtUp {
                Text("Catching up with recorded activity…")
                    .font(.caption).foregroundStyle(manufacturerTheme.palette.amber)
            }
            if selected?.incomplete == true {
                Text("Some activity was missed or could not be retained. Totals and contract history are incomplete.")
                    .font(.caption).foregroundStyle(manufacturerTheme.palette.amber)
            }
            if store.storageFailed {
                Text("Session history could not be loaded or saved. Current changes may not survive an app restart.")
                    .font(.caption).foregroundStyle(manufacturerTheme.palette.red)
            }
            Text("Up to 12 tracking sessions are saved on this iPad. Changing ships does not reset a session.")
                .font(.caption).foregroundStyle(manufacturerTheme.palette.dim)
        }
    }
}
