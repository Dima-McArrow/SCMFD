import Foundation

/// Wire format of CSMFD protocol v2 (section 41 of CSMFD-discussion.md).
/// Pure data: no networking and no UI state. The transport encodes `ClientMessage`
/// and decodes `ServerMessage`; mapping into `DeckState` and observed `PartyState` happens elsewhere.
nonisolated enum ProtocolV2 {
    static let version = 2

    nonisolated static func encode(_ message: ClientMessage) throws -> Data {
        let encoder = JSONEncoder()
        // Valid either way, but "/wave2" instead of "\/wave2" keeps server-side logs readable.
        encoder.outputFormatting = .withoutEscapingSlashes
        return try encoder.encode(message)
    }

    nonisolated static func decode(_ data: Data) throws -> ServerMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeDate)
        return try decoder.decode(ServerMessage.self, from: data)
    }

    /// The server writes UTC with milliseconds; the spec examples also show whole seconds.
    nonisolated private static func decodeDate(_ decoder: any Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle().parse(text) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 UTC date: \(text)")
    }
}

nonisolated extension UUID {
    /// Lowercase form used by every example in the spec; `uuidString` is uppercase.
    var wireString: String { uuidString.lowercased() }
}

// MARK: - iPad → server

nonisolated struct ClientHello: Sendable, Equatable {
    var client = "CSMFD-iPad"
    let appVersion: String
    let deviceName: String
    /// nil before pairing. Sent as an explicit JSON null, never omitted.
    let token: String?
}

nonisolated enum ClientMessage: Sendable, Equatable {
    case hello(ClientHello)
    case pair(code: String)
    /// `id` is any unique string up to 64 characters; `unixMilliseconds` is echoed back in `pong`.
    case ping(id: String, unixMilliseconds: Int64)
    case key(id: UUID, KeyEvent)
    case wheel(id: UUID, WheelEvent)
    case chat(id: UUID, text: String)
    case releaseAll(id: UUID)
}

nonisolated extension ClientMessage: Encodable {
    private enum CodingKeys: String, CodingKey {
        case v, type, id, client, appVersion, deviceName, token, code, t, action, phase, key, mods, ms, text, step
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ProtocolV2.version, forKey: .v)
        switch self {
        case .hello(let hello):
            try container.encode("hello", forKey: .type)
            try container.encode(hello.client, forKey: .client)
            try container.encode(hello.appVersion, forKey: .appVersion)
            try container.encode(hello.deviceName, forKey: .deviceName)
            // Encoding the Optional itself writes `null`; synthesized code would drop the key,
            // and the server treats a missing required field as malformed.
            try container.encode(hello.token, forKey: .token)
        case .pair(let code):
            try container.encode("pair", forKey: .type)
            try container.encode(code, forKey: .code)
        case .ping(let id, let unixMilliseconds):
            try container.encode("ping", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(unixMilliseconds, forKey: .t)
        case .key(let id, let event):
            try container.encode("key", forKey: .type)
            try container.encode(id.wireString, forKey: .id)
            try container.encode(event.action.rawValue, forKey: .action)
            try container.encode(event.chord.key, forKey: .key)
            // Fixed order keeps the JSON deterministic; the server compares the set.
            let mods = KeyChord.Modifier.allCases.filter(event.chord.modifiers.contains).map(\.rawValue)
            try container.encode(mods, forKey: .mods)
            switch event.phase {
            case .down:
                try container.encode("down", forKey: .phase)
            case .up:
                try container.encode("up", forKey: .phase)
            case .hold(let milliseconds):
                try container.encode("hold", forKey: .phase)
                try container.encode(milliseconds, forKey: .ms)
            }
        case .wheel(let id, let event):
            try container.encode("wheel", forKey: .type)
            try container.encode(id.wireString, forKey: .id)
            try container.encode(event.action.rawValue, forKey: .action)
            try container.encode(event.step.rawValue, forKey: .step)
        case .chat(let id, let text):
            try container.encode("chat", forKey: .type)
            try container.encode(id.wireString, forKey: .id)
            try container.encode(text, forKey: .text)
        case .releaseAll(let id):
            try container.encode("releaseAll", forKey: .type)
            try container.encode(id.wireString, forKey: .id)
        }
    }
}

// MARK: - Server → iPad

nonisolated struct ServerWelcome: Decodable, Sendable, Equatable {
    let server: String
    let serverVersion: String
    let serverId: UUID
    /// New on every server start; `seq` only orders states within one session.
    let sessionId: UUID
    /// New for every accepted authenticated connection.
    let connectionId: UUID
    /// `enter` or `f12`, a local server setting.
    let chatKey: String
}

nonisolated struct ServerPaired: Decodable, Sendable, Equatable {
    let serverId: UUID
    let token: String
}

nonisolated struct ServerPong: Decodable, Sendable, Equatable {
    let id: String
    let t: Int64
}

nonisolated struct ServerAck: Decodable, Sendable, Equatable {
    nonisolated enum Status: LenientWireEnum {
        case sent, ignored, rejected
        /// A status this build does not know. It settles the command as `CommandOutcome.unknown`: never `sent`
        /// (a toggle must not flip on it) and never retried, because the input may or may not have reached the game.
        case unrecognized(String)

        static let known: [Self] = [.sent, .ignored, .rejected]

        var wireValue: String {
            switch self {
            case .sent: "sent"
            case .ignored: "ignored"
            case .rejected: "rejected"
            case .unrecognized(let raw): raw
            }
        }
    }

    let id: UUID
    let status: Status
    /// Raw reason, present only for `rejected`. Kept as a string so a new server reason
    /// does not break ack correlation; use `rejectReason` for the known ones.
    let reason: String?

    var rejectReason: RejectReason? { reason.flatMap(RejectReason.init(rawValue:)) }
}

nonisolated enum RejectReason: String, Sendable {
    case gameNotFocused = "game_not_focused"
    case gameNotRunning = "game_not_running"
    case unknownAction = "unknown_action"
    case unknownKey = "unknown_key"
    case invalid
    case rateLimited = "rate_limited"
    case duplicate
    case busy
    case expired
    case inputFailed = "input_failed"
    case inputPaused = "input_paused"
    case cancelled
}

/// `reason` of `input_cancelled` / `auto_released` (41.10). Unknown values stay raw strings in `ServerError`.
nonisolated enum CancelReason: String, Sendable, CaseIterable {
    case focusLost = "focus_lost"
    case sessionLocked = "session_locked"
    case gameEnded = "game_ended"
    case shipContextChanged = "ship_context_changed"
    case paused
    case clientReplaced = "client_replaced"
    case revoked
    case disconnected
    case watchdog
    case shutdown
    case releaseAll = "release_all"
}

nonisolated struct ServerError: Decodable, Sendable, Equatable {
    /// Raw code: `malformed`, `pair_unavailable`, `input_cancelled`, `auto_released`...
    let code: String
    let message: String?
    /// Set for `input_cancelled` and `auto_released`: the hold or tap that ended.
    let commandId: UUID?
    /// Why the input ended: `focus_lost`, `ship_context_changed`, `release_all`...
    let reason: String?
}

/// A server enum that decodes a value this build does not know into `.unrecognized(word)` instead of failing.
///
/// A plain `String, Decodable` enum throws on a new value; `ServerConnection` turns that into
/// `.protocolViolation`, which never reconnects, so one new word from a newer server would end the link for good.
/// The word is kept, so the Debug screen shows what the server actually sent, and the case is typed, so every
/// `switch` must decide what an unrecognized value means (each conforming type documents its safe reading).
/// A wrong JSON type (a number instead of a string) still fails: that is a malformed message, not a new value.
nonisolated protocol LenientWireEnum: Decodable, Sendable, Equatable {
    /// Every case this build knows, i.e. all except `unrecognized`.
    static var known: [Self] { get }
    /// A value this build does not know, with the word the server sent.
    static func unrecognized(_ wireValue: String) -> Self
    /// The value as it travels on the wire.
    var wireValue: String { get }
}

nonisolated extension LenientWireEnum {
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self.known.first { $0.wireValue == raw } ?? .unrecognized(raw)
    }
}

/// A top-level key of a state message. Distinguishes "not sent" from a sent value,
/// because a missing key in a delta means "unchanged".
nonisolated enum StateField<Value: Sendable>: Sendable {
    case absent
    case value(Value)
}

nonisolated extension StateField: Equatable where Value: Equatable {}

nonisolated enum Confidence: LenientWireEnum {
    case confirmed, assumed, stale
    /// A confidence this build does not know. Read it like `.stale`, the weakest one, so nothing counts as
    /// confirmed by accident (today only the Debug screen shows confidence).
    case unrecognized(String)

    static let known: [Self] = [.confirmed, .assumed, .stale]

    var wireValue: String {
        switch self {
        case .confirmed: "confirmed"
        case .assumed: "assumed"
        case .stale: "stale"
        case .unrecognized(let raw): raw
        }
    }
}

nonisolated struct GameStatus: Decodable, Sendable, Equatable {
    let running: Bool
    let focused: Bool
    let build: String?
}

nonisolated struct LogStatus: Decodable, Sendable, Equatable {
    nonisolated enum Status: LenientWireEnum {
        case ready, missing, unreadable, catchingUp
        /// A log status this build does not know. Only the Debug screen shows the log status and no rule depends
        /// on it, so showing the word is safe.
        case unrecognized(String)

        static let known: [Self] = [.ready, .missing, .unreadable, .catchingUp]

        var wireValue: String {
            switch self {
            case .ready: "ready"
            case .missing: "missing"
            case .unreadable: "unreadable"
            case .catchingUp: "catchingUp"
            case .unrecognized(let raw): raw
            }
        }
    }

    let status: Status
    let generation: UUID
    let observedAt: Date?
}

nonisolated struct ShipStatus: Decodable, Sendable, Equatable {
    let name: String
    let model: String?
    let entityId: String?
    let manufacturerPrefix: String?
    let confidence: Confidence
    let observedAt: Date
}

nonisolated struct ShipContextStatus: Decodable, Sendable, Equatable {
    nonisolated enum Status: LenientWireEnum {
        case unknown, assumed, noShip
        /// A status this build does not know. Only `assumed` enables the Deck, so it stays off unless the user
        /// enables it manually.
        case unrecognized(String)

        static let known: [Self] = [.unknown, .assumed, .noShip]

        var wireValue: String {
            switch self {
            case .unknown: "unknown"
            case .assumed: "assumed"
            case .noShip: "noShip"
            case .unrecognized(let raw): raw
            }
        }
    }

    nonisolated enum Reason: LenientWireEnum {
        /// `clearDriver` comes only from servers older than 41.23; the tracker ignores it.
        case startup, channelJoined, clearDriver, channelLeft, vehicleDestroyed, gameEnded, logReset
        /// A reason this build does not know (a newer server may add one, 41.23). The Deck follows `status`;
        /// the theme and the keys stay as they are.
        case unrecognized(String)

        static let known: [Self] = [.startup, .channelJoined, .clearDriver, .channelLeft, .vehicleDestroyed,
                                    .gameEnded, .logReset]

        var wireValue: String {
            switch self {
            case .startup: "startup"
            case .channelJoined: "channelJoined"
            case .clearDriver: "clearDriver"
            case .channelLeft: "channelLeft"
            case .vehicleDestroyed: "vehicleDestroyed"
            case .gameEnded: "gameEnded"
            case .logReset: "logReset"
            case .unrecognized(let raw): raw
            }
        }
    }

    /// Grows on every ship-context transition (41.23).
    let revision: Int
    let status: Status
    /// Why the context changed. A new server reason decodes as `.unrecognized(word)`, not a decoding error.
    let reason: Reason
    let contextId: UUID?
    /// Last recognized manufacturer; may outlive the ship after a leave or destruction (theme only, not control).
    let manufacturerPrefix: String?
    let observedAt: Date?
}

nonisolated struct QuantumTargetStatus: Decodable, Sendable, Equatable {
    nonisolated enum Mode: LenientWireEnum {
        case unknown, freeMode, destination
        /// A mode this build does not know. The readout shows it like `.unknown` (". . ."); no target
        /// is invented from the names.
        case unrecognized(String)

        static let known: [Self] = [.unknown, .freeMode, .destination]

        var wireValue: String {
            switch self {
            case .unknown: "unknown"
            case .freeMode: "freeMode"
            case .destination: "destination"
            case .unrecognized(let raw): raw
            }
        }
    }

    let mode: Mode
    let internalName: String?
    let displayName: String?
    let confidence: Confidence
    let observedAt: Date?
}

nonisolated struct HangarRequestState: Decodable, Sendable, Equatable {
    let status: HangarRequestStatus
    /// The requestLanding command that started the wait.
    let commandId: UUID?
    let contextId: UUID?
    let since: Date?
    let updatedAt: Date?
}

nonisolated extension HangarRequestStatus: LenientWireEnum {
    static let known: [Self] = [.idle, .pending, .answered, .timeout]

    var wireValue: String {
        switch self {
        case .idle: "idle"
        case .pending: "pending"
        case .answered: "answered"
        case .timeout: "timeout"
        case .unrecognized(let raw): raw
        }
    }
}

nonisolated struct ServerState: Sendable, Equatable {
    let sessionId: UUID
    let seq: Int
    /// false: a full snapshot with every key; true: only changed top-level keys.
    let partial: Bool
    let game: StateField<GameStatus>
    let log: StateField<LogStatus>
    /// `.value(nil)` is an explicit JSON null: no assumed ship (ClearDriver, game ended...).
    let ship: StateField<ShipStatus?>
    let shipContext: StateField<ShipContextStatus>
    let qtTarget: StateField<QuantumTargetStatus>
    let hangarRequest: StateField<HangarRequestState>
}

nonisolated extension ServerState: Decodable {
    private enum CodingKeys: String, CodingKey {
        case sessionId, seq, partial, game, log, ship, shipContext, qtTarget, hangarRequest
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        seq = try container.decode(Int.self, forKey: .seq)
        partial = try container.decode(Bool.self, forKey: .partial)
        game = try Self.field(GameStatus.self, .game, in: container)
        log = try Self.field(LogStatus.self, .log, in: container)
        shipContext = try Self.field(ShipContextStatus.self, .shipContext, in: container)
        qtTarget = try Self.field(QuantumTargetStatus.self, .qtTarget, in: container)
        hangarRequest = try Self.field(HangarRequestState.self, .hangarRequest, in: container)

        // `ship` is the only key where null is a value. decodeIfPresent would turn both
        // "missing" and "null" into nil, which would either clear the ship on every delta
        // or never clear it.
        if !container.contains(.ship) {
            ship = .absent
        } else if try container.decodeNil(forKey: .ship) {
            ship = .value(nil)
        } else {
            ship = .value(try container.decode(ShipStatus.self, forKey: .ship))
        }

        if !partial {
            let missing = [game.isAbsent, log.isAbsent, ship.isAbsent, shipContext.isAbsent,
                           qtTarget.isAbsent, hangarRequest.isAbsent].contains(true)
            if missing {
                throw DecodingError.dataCorruptedError(
                    forKey: .partial, in: container,
                    debugDescription: "A full state must contain every top-level key"
                )
            }
        }
    }

    /// Present keys must hold an object: null is only allowed for `ship`, so decoding a
    /// non-optional type rejects it.
    private static func field<Value: Decodable & Sendable>(
        _ type: Value.Type,
        _ key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> StateField<Value> {
        guard container.contains(key) else { return .absent }
        return .value(try container.decode(type, forKey: key))
    }
}

nonisolated extension ServerState {
    /// The snapshot after applying `next` (41.8). A full state replaces everything; in a delta a missing
    /// key keeps the old value and a present key replaces the whole object (no deep merge). The result
    /// always has every key, so it is marked full.
    func merged(with next: ServerState) -> ServerState {
        guard next.partial else { return next }
        return ServerState(
            sessionId: next.sessionId,
            seq: next.seq,
            partial: false,
            game: next.game.keeping(game),
            log: next.log.keeping(log),
            ship: next.ship.keeping(ship),
            shipContext: next.shipContext.keeping(shipContext),
            qtTarget: next.qtTarget.keeping(qtTarget),
            hangarRequest: next.hangarRequest.keeping(hangarRequest)
        )
    }
}

nonisolated private extension StateField {
    var isAbsent: Bool {
        if case .absent = self { true } else { false }
    }

    /// This value if it was sent, otherwise the previous one.
    func keeping(_ previous: StateField) -> StateField {
        isAbsent ? previous : self
    }
}

nonisolated enum ServerMessage: Sendable, Equatable {
    case pairRequired
    case paired(ServerPaired)
    case welcome(ServerWelcome)
    case state(ServerState)
    case activity(ServerActivityPage)
    case ack(ServerAck)
    case pong(ServerPong)
    case error(ServerError)
    /// A message type this client does not know; the transport ignores it.
    case unknown(type: String)
}

nonisolated enum ProtocolV2Error: Error, Equatable {
    case unsupportedVersion(Int)
}

nonisolated extension ServerMessage: Decodable {
    private enum CodingKeys: String, CodingKey {
        case v, type
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .v)
        guard version == ProtocolV2.version else { throw ProtocolV2Error.unsupportedVersion(version) }
        // The payload types read their own keys from the same top-level object.
        switch try container.decode(String.self, forKey: .type) {
        case "pairRequired": self = .pairRequired
        case "paired": self = .paired(try ServerPaired(from: decoder))
        case "welcome": self = .welcome(try ServerWelcome(from: decoder))
        case "state": self = .state(try ServerState(from: decoder))
        case "activity": self = .activity(try ServerActivityPage(from: decoder))
        case "ack": self = .ack(try ServerAck(from: decoder))
        case "pong": self = .pong(try ServerPong(from: decoder))
        case "error": self = .error(try ServerError(from: decoder))
        case let other: self = .unknown(type: other)
        }
    }
}
