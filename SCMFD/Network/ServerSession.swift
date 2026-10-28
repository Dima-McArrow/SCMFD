import Foundation

/// Limits from section 41.6; the server enforces its own side independently.
nonisolated struct SessionConfiguration: Sendable {
    var appVersion: String
    var deviceName: String
    /// The server closes after 15 s without a ping.
    var pingInterval: Duration = .seconds(5)
    /// No message from the server for this long means the transport is gone.
    var livenessTimeout: Duration = .seconds(10)
    /// From hello (or a sent code) to the expected answer.
    var handshakeTimeout: Duration = .seconds(10)
    /// The server keeps a pairing connection open for its 120 s window.
    var pairingTimeout: Duration = .seconds(120)
    /// Commands awaiting an ack; the server queues at most 32.
    var maxPendingCommands = 32
    var acknowledgementTimeout: Duration = .seconds(15)
}

nonisolated enum SessionPhase: Equatable, Sendable {
    /// Transport not open yet.
    case idle
    case awaitingWelcome
    /// The server opened pairing; waiting for the user to type the code shown on the PC.
    case pairingRequired
    /// Code sent; waiting for `paired`.
    case pairing
    case ready(ServerWelcome)
    case closed(SessionCloseReason)
}

nonisolated enum SessionCloseReason: Equatable, Sendable {
    case acknowledgementTimeout
    case livenessTimeout
    case handshakeTimeout
    case pairingTimeout
    /// No pairing window is open on the PC.
    case pairingUnavailable
    /// `paired` or `welcome` came from a different server id than the pinned one.
    case serverIdentityMismatch
    case protocolViolation(String)
    case serverError(code: String)
    /// The WebSocket closed with this code; nil when it dropped without one.
    case closedByServer(code: Int?)
    case cancelled

    /// Reconnecting only helps with transient trouble. Replacement (4001), version (4002),
    /// authentication (4003) and revocation (4006) need the user, not a retry loop.
    var allowsReconnect: Bool {
        switch self {
        case .acknowledgementTimeout, .livenessTimeout, .handshakeTimeout:
            true
        case .closedByServer(let code):
            ![4001, 4002, 4003, 4006].contains(code)
        case .pairingTimeout, .pairingUnavailable, .serverIdentityMismatch, .protocolViolation, .serverError, .cancelled:
            false
        }
    }
}

nonisolated enum SessionCommand: Equatable, Sendable {
    case key(KeyEvent)
    case chat(String)
    case releaseAll
}

nonisolated enum CommandOutcome: Equatable, Sendable {
    case sent
    case ignored
    /// Raw server reason, e.g. `busy` or `game_not_focused`.
    case rejected(String?)
    /// The connection ended before an ack: the input may or may not have reached the game.
    /// Never retried automatically.
    case unknown
    case notSent(NotSentReason)

    nonisolated enum NotSentReason: Equatable, Sendable {
        case notConnected
        case tooManyPending
    }
}

nonisolated enum SessionEffect: Equatable, Sendable {
    case send(ClientMessage)
    /// Close the transport; the session is already in `.closed`.
    case close(SessionCloseReason)
    case savePairing(serverId: UUID, token: String)
    /// The server revoked this device (4006).
    case forgetPairing
    case pairingCodeRejected(code: String)
    /// The merged snapshot after an accepted state message, never a bare delta.
    case state(ServerState)
    case activity(ServerActivityPage)
    case commandFinished(UUID, CommandOutcome)
    /// A hold or tap that already got `sent` ended early (`input_cancelled`) or by the safety ceiling (`auto_released`).
    case inputEnded(commandId: UUID, code: String, reason: String?)
    case roundTrip(Duration)
    case serverError(code: String, message: String?)
}

/// Protocol v2 session as a pure state machine: events in, effects out.
/// It never touches the network or a clock, so handshake, timers and ack bookkeeping
/// are tested deterministically; the transport layer feeds it real sockets and time.
nonisolated struct ServerSession: Sendable {
    typealias Instant = ContinuousClock.Instant

    private(set) var phase: SessionPhase = .idle

    private let configuration: SessionConfiguration
    /// From the QR code or Keychain; nil only for a first manual pairing before `paired`.
    private var serverId: UUID?
    private var token: String?
    private var phaseStartedAt: Instant?
    private var lastReceivedAt: Instant?
    private var lastPingSentAt: Instant?
    /// The ping whose pong would give a round-trip time.
    private var awaitedPong: (id: String, sentAt: Instant)?
    private var pingCounter = 0
    /// Every state of this connection merged so far; its `seq` is the last one applied.
    private var snapshot: ServerState?
    private var pending: [UUID: Instant] = [:]

    init(configuration: SessionConfiguration, serverId: UUID?, token: String?) {
        self.configuration = configuration
        self.serverId = serverId
        self.token = token
    }

    // MARK: - Events

    /// TLS is verified and the WebSocket is open.
    mutating func transportOpened(at now: Instant) -> [SessionEffect] {
        guard phase == .idle else { return [] }
        enter(.awaitingWelcome, at: now)
        lastReceivedAt = now
        let hello = ClientHello(appVersion: configuration.appVersion, deviceName: configuration.deviceName, token: token)
        return [.send(.hello(hello))]
    }

    mutating func submitPairingCode(_ code: String, at now: Instant) -> [SessionEffect] {
        guard phase == .pairingRequired, code.count == 6, code.allSatisfy({ ("0"..."9").contains($0) }) else { return [] }
        enter(.pairing, at: now)
        return [.send(.pair(code: code))]
    }

    /// Commands are only sent on a ready session; nothing is queued for a later connection.
    mutating func send(_ command: SessionCommand, id: UUID, at now: Instant) -> [SessionEffect] {
        guard case .ready = phase else { return [.commandFinished(id, .notSent(.notConnected))] }
        guard pending.count < configuration.maxPendingCommands else {
            return [.commandFinished(id, .notSent(.tooManyPending))]
        }
        pending[id] = now
        switch command {
        case .key(let event): return [.send(.key(id: id, event))]
        case .chat(let text): return [.send(.chat(id: id, text: text))]
        case .releaseAll: return [.send(.releaseAll(id: id))]
        }
    }

    mutating func receive(_ message: ServerMessage, at now: Instant) -> [SessionEffect] {
        if case .closed = phase { return [] }
        lastReceivedAt = now

        switch message {
        case .pairRequired:
            guard phase == .awaitingWelcome else { return violation("pairRequired outside the handshake") }
            enter(.pairingRequired, at: now)
            return []

        case .paired(let paired):
            guard phase == .pairing else { return violation("paired without a sent code") }
            if let serverId, serverId != paired.serverId { return close(.serverIdentityMismatch) }
            serverId = paired.serverId
            token = paired.token
            // The server follows with welcome and a full state.
            enter(.awaitingWelcome, at: now)
            return [.savePairing(serverId: paired.serverId, token: paired.token)]

        case .welcome(let welcome):
            guard phase == .awaitingWelcome else { return violation("welcome outside the handshake") }
            if let serverId, serverId != welcome.serverId { return close(.serverIdentityMismatch) }
            serverId = welcome.serverId
            enter(.ready(welcome), at: now)
            snapshot = nil
            // The first ping is due one interval after welcome.
            lastPingSentAt = now
            return []

        case .state(let state):
            guard case .ready(let welcome) = phase else { return violation("state before welcome") }
            guard state.sessionId == welcome.sessionId else { return violation("state from another session") }
            if let snapshot {
                // Older or repeated snapshots are dropped, not applied.
                guard state.seq > snapshot.seq else { return [] }
            } else if state.partial {
                return violation("first state is a delta")
            }
            // Consumers always get the complete picture, never a bare delta.
            let merged = snapshot?.merged(with: state) ?? state
            snapshot = merged
            return [.state(merged)]

        case .activity(let page):
            guard case .ready(let welcome) = phase, page.sessionId == welcome.sessionId, page.isValid else {
                return violation("Invalid activity page or activity before welcome")
            }
            return [.activity(page)]

        case .ack(let ack):
            guard case .ready = phase else { return violation("ack before welcome") }
            // Late or unknown ids (e.g. after the client gave up) are ignored.
            guard pending.removeValue(forKey: ack.id) != nil else { return [] }
            let outcome: CommandOutcome = switch ack.status {
            case .sent: .sent
            case .ignored: .ignored
            case .rejected: .rejected(ack.reason)
            // A status this build does not know: the input may or may not have reached the game. Never `sent`,
            // never retried.
            case .unrecognized: .unknown
            }
            return [.commandFinished(ack.id, outcome)]

        case .pong(let pong):
            guard let awaitedPong, awaitedPong.id == pong.id else { return [] }
            self.awaitedPong = nil
            return [.roundTrip(now - awaitedPong.sentAt)]

        case .error(let error):
            return handle(error)

        case .unknown:
            return []
        }
    }

    /// A frame that could not be decoded: binary, too large or not protocol v2 JSON.
    mutating func receiveFailed(_ description: String) -> [SessionEffect] {
        violation(description)
    }

    /// Drives deadlines and pings; call it about once a second.
    mutating func tick(at now: Instant, wallClock: Date) -> [SessionEffect] {
        switch phase {
        case .idle, .closed:
            return []
        case .awaitingWelcome, .pairing:
            return expired(configuration.handshakeTimeout, at: now) ? close(.handshakeTimeout) : []
        case .pairingRequired:
            return expired(configuration.pairingTimeout, at: now) ? close(.pairingTimeout) : []
        case .ready:
            if let lastReceivedAt, now - lastReceivedAt >= configuration.livenessTimeout {
                return close(.livenessTimeout)
            }
            if pending.values.contains(where: { now - $0 >= configuration.acknowledgementTimeout }) {
                return close(.acknowledgementTimeout)
            }
            guard let lastPingSentAt, now - lastPingSentAt >= configuration.pingInterval else { return [] }
            pingCounter += 1
            let id = "p-\(pingCounter)"
            self.lastPingSentAt = now
            awaitedPong = (id: id, sentAt: now)
            let unixMilliseconds = Int64((wallClock.timeIntervalSince1970 * 1000).rounded())
            return [.send(.ping(id: id, unixMilliseconds: unixMilliseconds))]
        }
    }

    /// The WebSocket closed or failed underneath the session.
    mutating func transportClosed(code: Int?) -> [SessionEffect] {
        guard !isClosed else { return [] }
        let reason = SessionCloseReason.closedByServer(code: code)
        var effects = finish(reason)
        if code == 4006 { effects.append(.forgetPairing) }
        return effects
    }

    mutating func cancel() -> [SessionEffect] {
        close(.cancelled)
    }

    // MARK: - Helpers

    private var isClosed: Bool {
        if case .closed = phase { true } else { false }
    }

    private mutating func handle(_ error: ServerError) -> [SessionEffect] {
        switch error.code {
        case "pair_unavailable":
            return close(.pairingUnavailable)
        case "unsupported_version":
            return close(.serverError(code: error.code))
        case "input_cancelled", "auto_released":
            guard let commandId = error.commandId else { return violation("\(error.code) without commandId") }
            return [.inputEnded(commandId: commandId, code: error.code, reason: error.reason)]
        default:
            // A wrong code leaves the pairing window open; the user may try again.
            if phase == .pairing {
                phase = .pairingRequired
                return [.pairingCodeRejected(code: error.code)]
            }
            return [.serverError(code: error.code, message: error.message)]
        }
    }

    private mutating func enter(_ next: SessionPhase, at now: Instant) {
        phase = next
        phaseStartedAt = now
    }

    private func expired(_ timeout: Duration, at now: Instant) -> Bool {
        guard let phaseStartedAt else { return false }
        return now - phaseStartedAt >= timeout
    }

    private mutating func violation(_ description: String) -> [SessionEffect] {
        close(.protocolViolation(description))
    }

    /// Local close: settle pending commands and tell the transport to close.
    private mutating func close(_ reason: SessionCloseReason) -> [SessionEffect] {
        guard !isClosed else { return [] }
        return finish(reason) + [.close(reason)]
    }

    /// Pending commands end as unknown: an ack may have been lost, not the input.
    private mutating func finish(_ reason: SessionCloseReason) -> [SessionEffect] {
        phase = .closed(reason)
        let unresolved = pending.keys.sorted { $0.uuidString < $1.uuidString }
        pending.removeAll()
        return unresolved.map { .commandFinished($0, .unknown) }
    }
}
