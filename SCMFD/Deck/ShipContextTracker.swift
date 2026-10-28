import Foundation

/// What the Deck should do after a server state or a manual enable.
nonisolated struct DeckUpdate: Equatable, Sendable {
    let enabled: Bool
    let shipName: String?
    /// Keys back to their defaults and self-destruct disarmed; only after `vehicleDestroyed` (FIX-07).
    let resetKeys: Bool
    /// Mirrored from the server; the FE never sets these on its own (41.8, 41.13).
    var quantumTarget: QuantumTarget = .unknown
    /// nil means no server data yet, not `idle`.
    var hangarRequest: HangarRequestStatus? = nil
    /// Set only on a transition that moves the auto theme (FIX-07).
    var theme: ThemeChange? = nil
}

/// The auto theme for one ship-context transition. Tagged with the context, so two joins of the same
/// manufacturer (or two leaves) are two changes: a manual theme pick in between must be overridden.
nonisolated struct ThemeChange: Equatable, Sendable {
    let theme: AppTheme
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

/// Decides how merged server snapshots drive the Deck, the auto theme and the keys (41.23, FIX-07).
/// Pure, so every rule is unit-tested.
///
/// A ship context is `(sessionId, shipContext.revision)`. A new pair is a transition (join, leave, destroyed
/// vehicle, game end, log reset, server restart); the same pair (a delta, a reconnect, an enrichment) only
/// refreshes the mirrored readouts. The manual enable lasts until the next transition and is never persisted.
nonisolated struct ShipContextTracker: Sendable {
    private struct ContextKey: Equatable, Sendable {
        let sessionId: UUID
        let revision: Int
    }

    private var applied: ContextKey?
    /// The context the manual enable belongs to.
    private var override: ContextKey?
    private var status: ShipContextStatus.Status?
    private var shipName: String?
    private var quantumTarget: QuantumTarget = .unknown
    private var hangarRequest: HangarRequestStatus?

    /// `state` must be a merged snapshot (see `ServerState.merged(with:)`).
    mutating func receive(_ state: ServerState) -> DeckUpdate? {
        guard case .value(let context) = state.shipContext else { return nil }
        let key = ContextKey(sessionId: state.sessionId, revision: context.revision)
        let previous = applied
        let isTransition = key != previous
        applied = key
        if case .value(let ship) = state.ship { shipName = ship?.name }
        // The server resets both on a new context, so the FE only mirrors them.
        if case .value(let target) = state.qtTarget { quantumTarget = QuantumTarget(target) }
        if case .value(let request) = state.hangarRequest { hangarRequest = request.status }

        let reason = context.knownReason
        if reason == .clearDriver {
            // Servers before 41.23 still bump the revision when the pilot leaves the seat. That is not a
            // transition any more: the Deck keeps its state, and a manual enable moves to the new revision.
            if let override, override == previous { self.override = key }
        } else {
            status = context.status
        }
        // A transition (or a server restart) ends the manual enable; a reconnect to the same context does not.
        if override != key { override = nil }

        guard isTransition else { return update(resetKeys: false) }
        var result = update(resetKeys: reason == .vehicleDestroyed)
        if let theme = Self.theme(for: reason, context: context, state: state) {
            result.theme = ThemeChange(theme: theme, sessionId: state.sessionId, revision: context.revision)
        }
        return result
    }

    /// The auto theme a transition asks for; nil keeps the current theme.
    private static func theme(for reason: ShipContextStatus.Reason, context: ShipContextStatus,
                              state: ServerState) -> AppTheme? {
        switch reason {
        case .channelJoined:
            // The context prefix first, then the ship's (41.9). Unknown prefixes keep the current theme.
            var shipPrefix: String?
            if case .value(let ship) = state.ship { shipPrefix = ship?.manufacturerPrefix }
            guard let prefix = context.manufacturerPrefix ?? shipPrefix,
                  let manufacturer = Manufacturer(logPrefix: prefix) else { return nil }
            return .manufacturer(manufacturer)
        case .channelLeft, .vehicleDestroyed, .gameEnded, .logReset:
            return .standard
        case .startup, .clearDriver, .unknown:
            return nil
        }
    }

    /// Enable Deck: valid until the next transition, survives a reconnect. Sends nothing to the game.
    /// nil when no server context is known yet; the caller then enables the Deck locally.
    mutating func enableManually() -> DeckUpdate? {
        guard let applied else { return nil }
        override = applied
        return update(resetKeys: false)
    }

    /// The link is down: readouts become "no data". The Deck, the theme and the keys stay as they are,
    /// and the next connection's full snapshot restores everything.
    mutating func connectionLost() {
        quantumTarget = .unknown
        hangarRequest = nil
    }

    private func update(resetKeys: Bool) -> DeckUpdate {
        DeckUpdate(enabled: isEnabled, shipName: shipName, resetKeys: resetKeys,
                   quantumTarget: quantumTarget, hangarRequest: hangarRequest)
    }

    private var isEnabled: Bool {
        // `unknown` (server started mid-flight) and `noShip` both need the manual enable.
        status == .assumed || override != nil
    }
}
