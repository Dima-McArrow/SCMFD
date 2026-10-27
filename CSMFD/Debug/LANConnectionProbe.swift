import Foundation
import Network
import Observation

/// One-shot TCP reachability check. Never sends credentials or game commands.
@MainActor
@Observable
final class LANConnectionProbe {
    struct Entry: Identifiable {
        let id = UUID()
        let date = Date()
        let message: String
    }

    private(set) var isRunning = false
    private(set) var status: LocalizedStringResource = "Not checked"
    private(set) var entries: [Entry] = []

    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var attemptID: UUID?

    func start(host: String, port: String) {
        stop()
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = port.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PrivateIPv4.isValid(host),
              !port.isEmpty, port.allSatisfy({ $0 >= "0" && $0 <= "9" }),
              let rawPort = UInt16(port), rawPort > 0,
              let endpointPort = NWEndpoint.Port(rawValue: rawPort) else {
            status = "Invalid address"
            record(String(localized: "Enter a private IPv4 address and a port from 1 to 65535."))
            return
        }

        let id = UUID()
        attemptID = id
        isRunning = true
        status = "Connecting…"
        record("TCP → \(host):\(rawPort)")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: endpointPort, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.attemptID == id else { return }
                switch state {
                case .ready:
                    self.status = "TCP reachable"
                    self.record(String(localized: "TCP connection established. TLS, WebSocket and server identity are not verified."))
                    self.finish()
                case .waiting(let error):
                    self.status = "Waiting for network"
                    self.record(String(localized: "Waiting: \(error.localizedDescription)"))
                case .failed(let error):
                    self.status = "Connection failed"
                    self.record(error.localizedDescription)
                    self.finish()
                default:
                    break
                }
            }
        }
        connection.start(queue: .main)
        timeout = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }
            guard let self, self.attemptID == id else { return }
            self.status = "Connection timed out"
            self.record(String(localized: "No connection within 10 seconds. Check the IP, listener, firewall and Local Network permission."))
            self.finish()
        }
    }

    func stop() {
        guard isRunning else { return }
        status = "Cancelled"
        record(String(localized: "Check cancelled."))
        finish()
    }

    func clearLog() {
        entries.removeAll()
    }

    private func finish() {
        attemptID = nil
        timeout?.cancel()
        timeout = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
        isRunning = false
    }

    private func record(_ message: String) {
        entries.append(Entry(message: message))
        if entries.count > 50 {
            entries.removeFirst(entries.count - 50)
        }
    }
}
