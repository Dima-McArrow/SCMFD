import SwiftUI

/// Read-only view of the app's server connection: phase, server, round trip and the latest state.
/// Pairing and connecting live in Connect to PC (tap the link status in the top bar).
struct SecureConnectionDebugSection: View {
    @Environment(\.manufacturerTheme) private var theme
    let connection: ServerConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step 2 · Server connection")
                    .foregroundStyle(theme.palette.accent)
                Text("Live feedback from the app's connection. Pair or reconnect from the link status in the top bar.")
                    .font(.callout)
                    .foregroundStyle(theme.palette.dim)
            }

            Text(verbatim: phaseLine)
                .font(.headline)
                .accessibilityAddTraits(.updatesFrequently)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                row("Paired PC", connection.pairedServer.map { "\($0.host):\($0.port) · \($0.serverId.wireString.prefix(8))" } ?? "none")
                if case .ready(let welcome) = connection.phase {
                    row("Server", "\(welcome.server) \(welcome.serverVersion) · chat key \(welcome.chatKey)")
                    row("Session", "\(welcome.sessionId.wireString.prefix(8)) · connection \(welcome.connectionId.wireString.prefix(8))")
                }
                if let roundTrip = connection.roundTrip {
                    row("Round trip", roundTrip.formatted(.units(allowed: [.milliseconds], width: .abbreviated)))
                }
                if let state = connection.latestState {
                    ForEach(stateRows(state), id: \.0) { name, value in
                        row(name, value)
                    }
                }
            }
            .font(.callout.monospaced())
        }
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(verbatim: name)
                .foregroundStyle(theme.palette.dim)
            Text(verbatim: value)
                .textSelection(.enabled)
        }
    }

    private var phaseLine: String {
        switch connection.phase {
        case .idle: connection.isCapturingFingerprint ? "Reading certificate…" : "Not connected"
        case .awaitingWelcome: "Connecting…"
        case .pairingRequired: "Waiting for the pairing code"
        case .pairing: "Checking code…"
        case .ready: "Connected"
        case .closed(let reason): "Closed: \(reason)"
        }
    }

    /// Only the keys this state carried; a delta leaves the others unchanged.
    private func stateRows(_ state: ServerState) -> [(String, String)] {
        var rows = [("State", "seq \(state.seq)\(state.partial ? " (delta)" : " (full)")")]
        if case .value(let game) = state.game {
            rows.append(("Game", "\(game.running ? "running" : "not running")\(game.focused ? ", focused" : "") · build \(game.build ?? "?")"))
        }
        if case .value(let log) = state.log {
            rows.append(("Game.log", log.status.wireValue))
        }
        if case .value(let ship) = state.ship {
            rows.append(("Ship", ship.map { "\($0.name) · \($0.confidence.wireValue)" } ?? "none"))
        }
        if case .value(let context) = state.shipContext {
            rows.append(("Context", "r\(context.revision) \(context.status.wireValue) · \(context.reason.wireValue)"))
        }
        if case .value(let target) = state.qtTarget {
            rows.append(("QT target", target.displayName ?? target.internalName ?? target.mode.wireValue))
        }
        if case .value(let request) = state.hangarRequest {
            rows.append(("ATC", request.status.wireValue))
        }
        return rows
    }
}
