import Foundation

/// Wire format of CSMFD protocol v2 (section 41 of CSMFD-discussion.md).
/// Pure data: no networking and no UI state. The transport encodes `ClientMessage`
/// and decodes `ServerMessage`; mapping into `DeckState` happens elsewhere.
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
    case chat(id: UUID, text: String)
    case releaseAll(id: UUID)
}

nonisolated extension ClientMessage: Encodable {
    private enum CodingKeys: String, CodingKey {
        case v, type, id, client, appVersion, deviceName, token, code, t, action, phase, key, mods, ms, text
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
    nonisolated enum Status: String, Decodable, Sendable {
        case sent, ignored, rejected
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

nonisolated struct ServerError: Decodable, Sendable, Equatable {
    /// Raw code: `malformed`, `pair_unavailable`, `input_cancelled`, `auto_released`...
    let code: String
    let message: String?
    /// Set for `input_cancelled` and `auto_released`: the hold or tap that ended.
    let commandId: UUID?
    /// Why the input ended: `focus_lost`, `ship_context_changed`, `release_all`...
    let reason: String?
}

/// A top-level key of a state message. Distinguishes "not sent" from a sent value,
/// because a missing key in a delta means "unchanged".
nonisolated enum StateField<Value: Sendable>: Sendable {
    case absent
    case value(Value)
}

nonisolated extension StateField: Equatable where Value: Equatable {}

nonisolated enum Confidence: String, Decodable, Sendable {
    case confirmed, assumed, stale
}

nonisolated struct GameStatus: Decodable, Sendable, Equatable {
    let running: Bool
    let focused: Bool
    let build: String?
}

nonisolated struct LogStatus: Decodable, Sendable, Equatable {
    nonisolated enum Status: String, Decodable, Sendable {
        case ready, missing, unreadable, catchingUp
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
    nonisolated enum Status: String, Decodable, Sendable {
        case unknown, assumed, noShip
    }

    nonisolated enum Reason: String, Decodable, Sendable {
        case startup, channelJoined, clearDriver, channelLeft, gameEnded, logReset
    }

    /// Grows on every processed ship-context transition, including a repeated ClearDriver.
    let revision: Int
    let status: Status
    let reason: Reason
    let contextId: UUID?
    /// Last recognized manufacturer; may outlive the ship after ClearDriver (theme only, not control).
    let manufacturerPrefix: String?
    let observedAt: Date?
}

nonisolated struct QuantumTargetStatus: Decodable, Sendable, Equatable {
    nonisolated enum Mode: String, Decodable, Sendable {
        case unknown, freeMode, destination
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

nonisolated extension HangarRequestStatus: Decodable {}

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

nonisolated private extension StateField {
    var isAbsent: Bool {
        if case .absent = self { true } else { false }
    }
}

nonisolated enum ServerMessage: Sendable, Equatable {
    case pairRequired
    case paired(ServerPaired)
    case welcome(ServerWelcome)
    case state(ServerState)
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
        case "ack": self = .ack(try ServerAck(from: decoder))
        case "pong": self = .pong(try ServerPong(from: decoder))
        case "error": self = .error(try ServerError(from: decoder))
        case let other: self = .unknown(type: other)
        }
    }
}
