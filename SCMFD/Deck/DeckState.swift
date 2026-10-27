import Observation
import SwiftUI

/// Tablet-side state of the deck. Lit keys follow the player's taps, not the game,
/// until the server starts reporting real ship state from Game.log.
/// Quantum travel target as reported by Game.log through the server.
nonisolated enum QuantumTarget: Equatable, Sendable {
    /// No data yet: the server is not connected or the log has not mentioned a target.
    case unknown
    /// Jump without a map route, aimed from the cockpit view.
    case freeMode
    /// A destination selected on the starmap.
    case destination(String)
}

/// Server-reported request state. An answer does not confirm clearance or open doors.
nonisolated enum HangarRequestStatus: String, Sendable {
    case idle, pending, answered, timeout

    var title: LocalizedStringResource {
        switch self {
        case .idle: "No active request"
        case .pending: "Awaiting response"
        case .answered: "Response received"
        case .timeout: "No confirmation · Retry"
        }
    }
}

@Observable
final class DeckState {
    private(set) var lit: Set<ShipAction> = []
    /// The console playground stays usable until an explicit ship-context update arrives.
    private(set) var isShipDisconnected = false
    @ObservationIgnored private var shipContext = ShipContextTracker()

    /// A merged snapshot from the server. Transport loss never calls this, so it does not disable the Deck.
    func receive(_ state: ServerState, connectionId: UUID) {
        guard let update = shipContext.receive(state, connectionId: connectionId) else { return }
        apply(update)
    }

    func apply(_ update: DeckUpdate) {
        if update.resetLocalState {
            resetLights()
            quantumTarget = .unknown
            hangarRequest = nil
        }
        shipName = update.shipName
        isShipDisconnected = !update.enabled
    }
    var selfDestructArmed = false
    /// Presentation placeholders for protocol v1; nil means no server observation yet.
    var shipName: String?
    var hangarRequest: HangarRequestStatus?

    /// Filled by the Game.log feed once the server link exists.
    var quantumTarget: QuantumTarget = .unknown

    func binding(for action: ShipAction) -> Binding<Bool> {
        Binding(
            get: { self.lit.contains(action) },
            set: { isLit in
                guard !self.isShipDisconnected else { return }
                if isLit {
                    self.lit.insert(action)
                    if action == .flightReady {
                        // Reflect startup on the tablet without sending extra power toggles.
                        self.lit.formUnion([.powerAll, .powerThrusters, .powerShields, .powerWeapons])
                    }
                } else {
                    self.lit.remove(action)
                    if action == .flightReady {
                        // Mirror shutdown across the same systems enabled by Flight Ready.
                        self.lit.subtract([.powerAll, .powerThrusters, .powerShields, .powerWeapons])
                    }
                }
            }
        )
    }

    /// Local override only: does not infer ship identity or send any game input.
    /// It lasts until the next ship-context transition or reconnect.
    func enableManually() {
        guard isShipDisconnected else { return }
        apply(shipContext.enableManually()
              ?? DeckUpdate(enabled: true, shipName: shipName, resetLocalState: true))
    }

    /// For when the lights drift from the game, e.g. after a respawn.
    func resetLights() {
        lit.removeAll()
        selfDestructArmed = false
    }
}
