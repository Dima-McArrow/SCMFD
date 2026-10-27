import SwiftUI

struct ConnectionDebugView: View {
    @Environment(\.manufacturerTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("debugServerIPv4") private var host = ""
    @AppStorage("debugServerPort") private var port = "47823"
    @State private var probe = LANConnectionProbe()
    /// Owned by ContentView: leaving this tab must not drop the deck's connection.
    let server: ServerConnection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Local connection check")
                        .font(.title2)
                    Text("Step 1 · TCP reachability")
                        .foregroundStyle(theme.palette.accent)
                    Text("Check that the Windows server port is reachable from this device. This does not connect the Deck or verify TLS, WebSocket, pairing or game input.")
                        .font(.callout)
                        .foregroundStyle(theme.palette.dim)
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Windows IPv4 address", text: $host, prompt: Text(verbatim: "192.168.1.42"))
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", text: $port)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Check connection", systemImage: "network") {
                            probe.start(host: host, port: port)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(probe.isRunning)
                        if probe.isRunning {
                            Button("Cancel") { probe.stop() }
                                .buttonStyle(.bordered)
                        }
                    }
                    Text(probe.status)
                        .font(.headline)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("On Windows")
                        .font(.headline)
                    Text("Start the server on the PC’s private IPv4 address, port 47823. Allow inbound TCP for that app on your Private network. Both devices must have a route to each other; guest Wi-Fi may block this.")
                    Text("On iPad, allow Local Network access when prompted. If the first check times out while granting permission, run it again.")
                    Text("A successful check opens and immediately closes a TCP connection without sending application data. A TLS server may log this as an incomplete handshake.")
                }
                .font(.callout)
                .foregroundStyle(theme.palette.dim)

                ConnectionProbeLog(title: "Connection log", entries: probe.entries, onClear: probe.clearLog)

                SecureConnectionDebugSection(connection: server)

                ConnectionProbeLog(title: "Secure connection log", entries: server.entries, onClear: server.clearLog)
            }
            .padding(20)
            .frame(maxWidth: 850, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(theme.palette.text)
        .background(theme.palette.panel.opacity(0.35))
        .onDisappear { probe.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { probe.stop() }
        }
    }
}

/// A timestamped line in one of the Debug logs.
protocol ConnectionLogEntry: Identifiable {
    var date: Date { get }
    var message: String { get }
}

extension LANConnectionProbe.Entry: ConnectionLogEntry {}
extension ServerConnection.Entry: ConnectionLogEntry {}

private struct ConnectionProbeLog<Entry: ConnectionLogEntry>: View {
    let title: LocalizedStringResource
    let entries: [Entry]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Clear log", action: onClear)
                    .disabled(entries.isEmpty)
            }
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.date, format: .dateTime.hour().minute().second())
                        .font(.caption.monospaced())
                    Text(verbatim: entry.message)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }
}

#Preview("Debug / LAN") {
    ConnectionDebugView(server: ServerConnection(store: ServerTrustStore(service: "com.csmfd.preview")))
        .manufacturerTheme(.drake)
}
