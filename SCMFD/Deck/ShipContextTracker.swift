import Foundation

/// What the Deck should do after a server state or a manual enable.
nonisolated struct DeckUpdate: Equatable, Sendable {
    let enabled: Bool
    let shipName: String?
    /// Turn lights off and disarm self-destruct.
    let resetLocalState: Bool
    /// Mirrored from the server; the FE never sets these on its own (41.8, 41.13).
    var quantumTarget: QuantumTarget = .unknown
    /// nil means no server data yet, not `idle`.
    var hangarRequest: HangarRequestStatus? = nil
    /// Set only on a `channelJoined` transition with a known manufacturer; drives the auto theme (FIX-04).
    var join: ShipJoin? = nil
}

/// The player joined a ship channel. Unique per context, so joining the same manufacturer twice is two events
/// (a manual theme pick in between must be overridden by the second join).
nonisolated struct ShipJoin: Equatable, Sendable {
    let manufacturer: Manufacturer
    let sessionId: UUID
    let revision: Int
}

nonisolated extension QuantumTarget {
    /// The UI prefers `displayName` (41.8). Today the server sends only the technical `internalName`; it is
    /// shown as is, without guessing a prettier name.
    init(_ status: QuantumTargetStatus) {
        switch status.mode {
        case .unknown:
            self = .unknown
        case .freeMode:
            self = .freeMode
        case .destination:
            if let name = status.displayName ?? status.internalName {
                self = .destination(name)
            } else {
                self = .unknown
            }
        }
    }
}

/// Decides how merged server snapshots drive the Deck (41.9, 41.17). Pure, so every rule is unit-tested.
///
/// A ship context is `(sessionId, shipContext.revision)`. A new pair is a transition (join, ClearDriver,
/// game end, server restart); the same pair only refreshes the ship label. The manual override belongs to
/// one context on one connection and is never persisted.
nonisolated struct ShipContextTracker: Sendable {
    private struct ContextKey: Equatable, Sendable {
        let sessionId: UUID
        let revision: Int
    }

    private struct Override: Equatable, Sendable {
        let context: ContextKey
        let connectionId: UUID
    }

    private var applied: ContextKey?
    private var connectionId: UUID?
    private var override: Override?
    private var status: ShipContextStatus.Status?
    private var shipName: String?
    private var quantumTarget: QuantumTarget = .unknown
    private var hangarRequest: HangarRequestStatus?

    /// `state` must be a merged snapshot (see `ServerState.merged(with:)`).
    mutating func receive(_ state: ServerState, connectionId: UUID) -> DeckUpdate? {
        guard case .value(let context) = state.shipContext else { return nil }
        let key = ContextKey(sessionId: state.sessionId, revision: context.revision)
        let isTransition = key != applied
        applied = key
        self.connectionId = connectionId
        status = context.status
        if case .value(let ship) = state.ship { shipName = ship?.name }
        // The server resets both on a new context, so the FE only mirrors them.
        if case .value(let target) = state.qtTarget { quantumTarget = QuantumTarget(target) }
        if case .value(let request) = state.hangarRequest { hangarRequest = request.status }
        // A transition, a reconnect or a server restart all end the override.
        if let override, override != Override(context: key, connectionId: connectionId) {
            self.override = nil
        }
        var result = update(enabled: isEnabled, resetLocalState: isTransition)
        if isTransition, context.reason == .channelJoined {
            result.join = Self.join(context: context, state: state)
        }
        return result
    }

    /// The context prefix first, then the ship's (41.9). Unknown prefixes keep the current theme.
    private static func join(context: ShipContextStatus, state: ServerState) -> ShipJoin? {
        var shipPrefix: String?
        if case .value(let ship) = state.ship { shipPrefix = ship?.manufacturerPrefix }
        guard let prefix = context.manufacturerPrefix ?? shipPrefix,
              let manufacturer = Manufacturer(logPrefix: prefix) else { return nil }
        return ShipJoin(manufacturer: manufacturer, sessionId: state.sessionId, revision: context.revision)
    }

    /// Ties "Enable Deck manually" to the current context and connection. Sends nothing to the game.
    /// nil when no server context is known yet; the caller then enables the Deck locally.
    mutating func enableManually() -> DeckUpdate? {
        guard let applied, let connectionId else { return nil }
        override = Override(context: applied, connectionId: connectionId)
        return update(enabled: true, resetLocalState: true)
    }

    /// The link is down: readouts become "no data". The Deck stays as it is (transport loss is not ClearDriver),
    /// and the next connection's full snapshot restores everything.
    mutating func connectionLost() {
        quantumTarget = .unknown
        hangarRequest = nil
    }

    private func update(enabled: Bool, resetLocalState: Bool) -> DeckUpdate {
        DeckUpdate(enabled: enabled, shipName: shipName, resetLocalState: resetLocalState,
                   quantumTarget: quantumTarget, hangarRequest: hangarRequest)
    }

    private var isEnabled: Bool {
        // `unknown` (server started mid-flight) and `noShip` both need the manual override.
        status == .assumed || override != nil
    }
}
