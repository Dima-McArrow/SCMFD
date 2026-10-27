import Foundation

/// What the Deck should do after a server state or a manual enable.
nonisolated struct DeckUpdate: Equatable, Sendable {
    let enabled: Bool
    let shipName: String?
    /// Turn lights off, disarm self-destruct and clear local QT/ATC.
    let resetLocalState: Bool
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

    /// `state` must be a merged snapshot (see `ServerState.merged(with:)`).
    mutating func receive(_ state: ServerState, connectionId: UUID) -> DeckUpdate? {
        guard case .value(let context) = state.shipContext else { return nil }
        let key = ContextKey(sessionId: state.sessionId, revision: context.revision)
        let isTransition = key != applied
        applied = key
        self.connectionId = connectionId
        status = context.status
        if case .value(let ship) = state.ship { shipName = ship?.name }
        // A transition, a reconnect or a server restart all end the override.
        if let override, override != Override(context: key, connectionId: connectionId) {
            self.override = nil
        }
        return DeckUpdate(enabled: isEnabled, shipName: shipName, resetLocalState: isTransition)
    }

    /// Ties "Enable Deck manually" to the current context and connection. Sends nothing to the game.
    /// nil when no server context is known yet; the caller then enables the Deck locally.
    mutating func enableManually() -> DeckUpdate? {
        guard let applied, let connectionId else { return nil }
        override = Override(context: applied, connectionId: connectionId)
        return DeckUpdate(enabled: true, shipName: shipName, resetLocalState: true)
    }

    private var isEnabled: Bool {
        // `unknown` (server started mid-flight) and `noShip` both need the manual override.
        status == .assumed || override != nil
    }
}
