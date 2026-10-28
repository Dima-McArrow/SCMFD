import Foundation
import Observation
import OSLog

nonisolated extension SessionConfiguration {
    /// `UIDevice.name` would need UIKit; the PC shows this name in its trusted devices list.
    static let app = SessionConfiguration(
        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        deviceName: "iPad"
    )
}

/// Drives `ServerSession` over a real WebSocket: TLS pinning, one send loop, one receive loop
/// and a one-second tick. All protocol decisions stay in the session.
@MainActor
@Observable
final class ServerConnection {
    struct Entry: Identifiable {
        let id = UUID()
        let date = Date()
        let message: String
    }

    private(set) var phase: SessionPhase = .idle
    private(set) var pairedServer: PairedServer?
    private(set) var isCapturingFingerprint = false
    /// Fingerprint read in manual pairing, waiting for the user to compare it with the PC.
    private(set) var capturedFingerprint: CapturedFingerprint?
    private(set) var roundTrip: Duration?
    private(set) var latestState: ServerState?
    private(set) var entries: [Entry] = []

    struct CapturedFingerprint: Equatable {
        let host: String
        let port: UInt16
        let fingerprint: Data

        var grouped: String {
            PairingPayload(host: host, port: port, serverId: UUID(), fingerprint: fingerprint).groupedFingerprint
        }
    }

    @ObservationIgnored var onActivity: ((ServerActivityPage) -> Void)?
    /// Merged snapshot. The ship context is keyed by `(sessionId, revision)`, not by connection (FIX-07).
    @ObservationIgnored var onState: ((ServerState) -> Void)?
    @ObservationIgnored var onCommandFinished: ((UUID, CommandOutcome) -> Void)?
    @ObservationIgnored var onInputEnded: ((UUID, String?) -> Void)?

    @ObservationIgnored private let store: ServerTrustStore
    @ObservationIgnored private let configuration: SessionConfiguration
    @ObservationIgnored private var session: ServerSession?
    @ObservationIgnored private var target: Target?
    @ObservationIgnored private var urlSession: URLSession?
    @ObservationIgnored private var task: URLSessionWebSocketTask?
    @ObservationIgnored private var outbound: AsyncStream<String>.Continuation?
    @ObservationIgnored private var loops: [Task<Void, Never>] = []
    /// Callbacks from an older socket compare against this and do nothing.
    @ObservationIgnored private var attempt = UUID()
    /// For the log only: the session emits merged snapshots, so the wire kind is noted on arrival.
    @ObservationIgnored private var incomingStateIsDelta = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.csmfd.app", category: "Server")
    /// Only sessions of a stored pairing reconnect; pairing attempts and manual disconnects do not.
    @ObservationIgnored private var reconnectsAutomatically = false
    @ObservationIgnored private var reconnectAttempt = 0
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?

    /// 1, 2, 4, 8, 16, then 30 seconds between attempts.
    nonisolated static func reconnectDelay(afterFailures failures: Int) -> Int {
        min(30, 1 << min(failures, 5))
    }

    private struct Target {
        let host: String
        let port: UInt16
        let fingerprint: Data
    }

    init(store: ServerTrustStore = ServerTrustStore(), configuration: SessionConfiguration = .app) {
        self.store = store
        self.configuration = configuration
        do {
            pairedServer = try store.load()
        } catch {
            record("Keychain read failed: \(error)")
        }
    }

    // MARK: - Public API

    /// Reconnect to the paired server with its stored token. A user-initiated call starts the
    /// backoff from one second again.
    func connect() {
        reconnectAttempt = 0
        openPairedSession()
    }

    private func openPairedSession() {
        guard let server = pairedServer else { return }
        reconnectsAutomatically = true
        start(Target(host: server.host, port: server.port, fingerprint: server.fingerprint),
              serverId: server.serverId, token: server.token)
    }

    /// Pair with the server from a scanned QR code; the fingerprint is already trusted.
    func pair(with payload: PairingPayload) {
        reconnectsAutomatically = false
        start(Target(host: payload.host, port: payload.port, fingerprint: payload.fingerprint),
              serverId: payload.serverId, token: nil)
    }

    /// Manual pairing, first half: read the certificate fingerprint and abort without sending anything.
    func captureFingerprint(host: String, port: UInt16) {
        reconnectsAutomatically = false
        reconnectTask?.cancel()
        reconnectTask = nil
        update { $0.cancel() }
        teardown()
        capturedFingerprint = nil
        isCapturingFingerprint = true
        let attempt = UUID()
        self.attempt = attempt

        let delegate = PinnedTLSDelegate(
            mode: .captureFingerprint,
            onFingerprint: { [weak self] fingerprint in
                // A `let` copy of the weak reference is Sendable; the captured weak var is not.
                let connection = self
                Task { @MainActor in connection?.captured(fingerprint, host: host, port: port, attempt: attempt) }
            },
            onFailure: { [weak self] failure in
                let connection = self
                await MainActor.run { connection?.pinFailed(failure, attempt: attempt) }
            }
        )
        guard let task = makeTask(host: host, port: port, delegate: delegate) else { return }
        record("Reading certificate of \(host):\(port)")
        task.resume()
        loops = [Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, self.attempt == attempt, self.isCapturingFingerprint else { return }
            self.record("No certificate within 10 s. Check the address, firewall and that the server is running.")
            self.teardown()
        }]
    }

    /// Manual pairing, second half: the user confirmed the fingerprint matches the PC.
    func pairWithCapturedFingerprint() {
        guard let captured = capturedFingerprint else { return }
        capturedFingerprint = nil
        reconnectsAutomatically = false
        start(Target(host: captured.host, port: captured.port, fingerprint: captured.fingerprint),
              serverId: nil, token: nil)
    }

    func submitPairingCode(_ code: String) {
        update { $0.submitPairingCode(code, at: .now) }
    }

    /// Sends one command; the outcome arrives through `onCommandFinished`.
    /// Callers that wait for the outcome pass their own id and register before sending.
    @discardableResult
    func send(_ command: SessionCommand, id: UUID = UUID()) -> UUID {
        if session == nil {
            onCommandFinished?(id, .notSent(.notConnected))
        } else {
            update { $0.send(command, id: id, at: .now) }
        }
        return id
    }

    func disconnect() {
        reconnectsAutomatically = false
        reconnectTask?.cancel()
        reconnectTask = nil
        if session != nil, task != nil {
            update { $0.cancel() }
        }
        teardown()
        isCapturingFingerprint = false
    }

    func forgetPairing() {
        disconnect()
        do {
            try store.delete()
            pairedServer = nil
            record("Pairing removed from this iPad")
        } catch {
            record("Keychain delete failed: \(error)")
        }
    }

    func clearLog() {
        entries.removeAll()
    }

    // MARK: - Connection lifecycle

    private func start(_ target: Target, serverId: UUID?, token: String?) {
        reconnectTask?.cancel()
        reconnectTask = nil
        update { $0.cancel() }
        teardown()
        let attempt = UUID()
        self.attempt = attempt
        self.target = target
        roundTrip = nil
        latestState = nil

        let delegate = PinnedTLSDelegate(mode: .pinned(target.fingerprint), onFailure: { [weak self] failure in
            let connection = self
            await MainActor.run { connection?.pinFailed(failure, attempt: attempt) }
        })
        guard let task = makeTask(host: target.host, port: target.port, delegate: delegate) else { return }

        let (stream, continuation) = AsyncStream.makeStream(of: String.self)
        outbound = continuation
        session = ServerSession(configuration: configuration, serverId: serverId, token: token)

        record("Connecting to wss://\(target.host):\(target.port)/csmfd")
        task.resume()
        // Queued sends wait for the handshake, which includes the pinned TLS check,
        // so hello cannot leave before the certificate is verified.
        update { $0.transportOpened(at: .now) }
        loops = [
            sendLoop(stream, task: task, attempt: attempt),
            receiveLoop(task, attempt: attempt),
            tickLoop(attempt: attempt),
        ]
    }

    private func makeTask(host: String, port: UInt16, delegate: PinnedTLSDelegate) -> URLSessionWebSocketTask? {
        guard let url = URL(string: "wss://\(host):\(port)/csmfd") else {
            record("Invalid address \(host):\(port)")
            return nil
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 10
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let urlSession = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let task = urlSession.webSocketTask(with: url)
        // The server's limit for one logical message.
        task.maximumMessageSize = 16 * 1024
        self.urlSession = urlSession
        self.task = task
        return task
    }

    /// The only place that writes to the socket, so messages leave in order.
    private func sendLoop(_ stream: AsyncStream<String>, task: URLSessionWebSocketTask, attempt: UUID) -> Task<Void, Never> {
        Task { [weak self] in
            for await text in stream {
                do {
                    try await task.send(.string(text))
                } catch {
                    self?.transportEnded(task, error: error, attempt: attempt)
                    return
                }
            }
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask, attempt: UUID) -> Task<Void, Never> {
        Task { [weak self] in
            while true {
                let message: URLSessionWebSocketTask.Message
                do {
                    message = try await task.receive()
                } catch {
                    self?.transportEnded(task, error: error, attempt: attempt)
                    return
                }
                guard let self, self.attempt == attempt else { return }
                self.handle(message)
            }
        }
    }

    private func tickLoop(attempt: UUID) -> Task<Void, Never> {
        Task { [weak self] in
            while true {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self, self.attempt == attempt else { return }
                self.update { $0.tick(at: .now, wallClock: .now) }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            do {
                let decoded = try ProtocolV2.decode(Data(text.utf8))
                if case .state(let state) = decoded { incomingStateIsDelta = state.partial }
                update { $0.receive(decoded, at: .now) }
            } catch {
                update { $0.receiveFailed("Undecodable message: \(error)") }
            }
        case .data:
            update { $0.receiveFailed("Binary frame") }
        @unknown default:
            update { $0.receiveFailed("Unknown frame") }
        }
    }

    private func transportEnded(_ task: URLSessionWebSocketTask, error: any Error, attempt: UUID) {
        guard self.attempt == attempt else { return }
        let code = task.closeCode == .invalid ? nil : task.closeCode.rawValue
        record("Transport ended (\(code.map(String.init) ?? "no close code")): \(error.localizedDescription)")
        update { $0.transportClosed(code: code) }
        teardown()
    }

    private func pinFailed(_ failure: CertificatePin.Failure, attempt: UUID) {
        guard self.attempt == attempt else { return }
        switch failure {
        case .fingerprintMismatch:
            record("Certificate fingerprint does NOT match the paired server. Nothing was sent.")
            update { $0.pinRejected() }
        case .noCertificate:
            record("The server presented no certificate.")
        case .untrusted(let description):
            record("Pinned certificate rejected: \(description)")
        }
    }

    private func captured(_ fingerprint: Data, host: String, port: UInt16, attempt: UUID) {
        guard self.attempt == attempt else { return }
        capturedFingerprint = CapturedFingerprint(host: host, port: port, fingerprint: fingerprint)
        record("Certificate read. Compare the fingerprint with the Pair window on the PC.")
        teardown()
    }

    /// Stops loops and the socket; the session keeps its final phase for display.
    private func teardown() {
        attempt = UUID()
        loops.forEach { $0.cancel() }
        loops.removeAll()
        outbound?.finish()
        outbound = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isCapturingFingerprint = false
    }

    // MARK: - Effects

    private func update(_ event: (inout ServerSession) -> [SessionEffect]) {
        guard var session else { return }
        let wasClosed = if case .closed = phase { true } else { false }
        let effects = event(&session)
        self.session = session
        phase = session.phase
        apply(effects)
        switch phase {
        case .ready:
            reconnectAttempt = 0
        case .closed(let reason) where !wasClosed:
            scheduleReconnect(after: reason)
        default:
            break
        }
    }

    private func scheduleReconnect(after reason: SessionCloseReason) {
        guard reconnectsAutomatically, reason.allowsReconnect, pairedServer != nil else { return }
        let delay = Self.reconnectDelay(afterFailures: reconnectAttempt)
        reconnectAttempt += 1
        record("Reconnecting in \(delay) s")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.openPairedSession()
        }
    }

    private func apply(_ effects: [SessionEffect]) {
        for effect in effects {
            switch effect {
            case .send(let message):
                guard let data = try? ProtocolV2.encode(message) else { continue }
                outbound?.yield(String(decoding: data, as: UTF8.self))
                if let line = Self.describe(message) { record("→ \(line)") }
            case .close(let reason):
                record("Session closed: \(reason)")
                teardown()
            case .savePairing(let serverId, let token):
                guard let target else { continue }
                let server = PairedServer(serverId: serverId, host: target.host, port: target.port,
                                          fingerprint: target.fingerprint, token: token)
                do {
                    try store.save(server)
                    pairedServer = server
                    reconnectsAutomatically = true
                    record("Paired. Token stored in the Keychain on this iPad only.")
                } catch {
                    record("Keychain save failed: \(error)")
                }
            case .forgetPairing:
                try? store.delete()
                pairedServer = nil
                record("The server revoked this iPad; pairing removed.")
            case .pairingCodeRejected(let code):
                record("Code rejected (\(code)). Check the code on the PC and try again.")
            case .state(let state):
                latestState = state
                record("← state seq \(state.seq)\(incomingStateIsDelta ? " (delta)" : " (full)")")
                // ServerSession emits states only while ready.
                if case .ready = phase { onState?(state) }
            case .activity(let page):
                onActivity?(page)
            case .commandFinished(let id, let outcome):
                record("← \(id.wireString.prefix(8)): \(outcome)")
                onCommandFinished?(id, outcome)
            case .inputEnded(let commandId, let code, let reason):
                record("← \(commandId.wireString.prefix(8)): \(code) (\(reason ?? "no reason"))")
                onInputEnded?(commandId, reason)
            case .roundTrip(let duration):
                roundTrip = duration
            case .serverError(let code, let message):
                record("← error \(code)\(message.map { ": \($0)" } ?? "")")
            }
        }
    }

    /// Log line without secrets: no token, no pairing code; pings are too frequent to list.
    private static func describe(_ message: ClientMessage) -> String? {
        switch message {
        case .hello(let hello): "hello (\(hello.token == nil ? "no token" : "stored token"))"
        case .pair: "pair (code sent)"
        case .ping: nil
        case .key(let id, let event): "key \(event.action.rawValue) \(event.phase.label) · \(id.wireString.prefix(8))"
        case .chat(let id, let text): "chat \(text) · \(id.wireString.prefix(8))"
        case .releaseAll(let id): "releaseAll · \(id.wireString.prefix(8))"
        }
    }

    private func record(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        entries.append(Entry(message: message))
        if entries.count > 100 {
            entries.removeFirst(entries.count - 100)
        }
    }
}
