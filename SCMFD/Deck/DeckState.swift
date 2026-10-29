import Observation
import SwiftUI

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
nonisolated enum HangarRequestStatus: Sendable, Equatable {
    case idle, pending, answered, timeout
    /// A status this build does not know, with the server's word (wire fallback). Never `idle` or anything that
    /// reads as an answer: `ShipContextTracker` turns it into "no data" (nil), and it looks like "no data" here too.
    case unrecognized(String)

    var title: LocalizedStringResource {
        switch self {
        case .idle: "No active request"
        case .pending: "Awaiting response"
        case .answered: "Response received"
        case .timeout: "No confirmation · Retry"
        case .unrecognized: "ATC · No data"
        }
    }
}

/// Tablet-side state of the deck. Lit keys follow the player's taps, not the game; the server only decides
/// whether the Deck is enabled and supplies the ship name, QT target and ATC status (`ShipContextTracker`).
@Observable
final class DeckState {
    /// Keys at app start and after a reset: landing gear down and coupled flight enabled.
    static let defaultLit: Set<ShipAction> = [.landingGear, .coupledMode]

    private(set) var lit: Set<ShipAction> = DeckState.defaultLit
    /// Off at app start in every mode, the console link included (FIX-07, first row): the first `channelJoined`
    /// or Enable Deck turns it on. Transport loss never changes it.
    private(set) var isShipDisconnected = true
    @ObservationIgnored private var shipContext = ShipContextTracker()

    /// A merged snapshot from the server. Transport loss never calls this, so it does not disable the Deck.
    func receive(_ state: ServerState) {
        guard let update = shipContext.receive(state) else { return }
        apply(update)
    }

    /// Shows QT and ATC as "no data" while the server link is down; keys and lights stay as they are.
    func connectionLost() {
        shipContext.connectionLost()
        quantumTarget = .unknown
        hangarRequest = nil
    }

    func apply(_ update: DeckUpdate) {
        if update.resetKeys { resetDeck() }
        shipName = update.shipName
        quantumTarget = update.quantumTarget
        hangarRequest = update.hangarRequest
        isShipDisconnected = !update.enabled
        if let theme = update.theme { lastThemeChange = theme }
    }

    /// The latest transition's theme; the app switches the auto theme when it changes.
    private(set) var lastThemeChange: ThemeChange?
    var selfDestructArmed = false
    /// Shared across both drums and page lifetimes; resetting the deck must not release a pending step.
    let wheelCommands = WheelCommandController()
    /// Mirrored from the server state; nil means no server data. The ship name survives a dropped link,
    /// the ATC status does not.
    var shipName: String?
    var hangarRequest: HangarRequestStatus?

    /// Mirrored from the server's `qtTarget`; `.unknown` without server data.
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
    /// It lasts until the next ship-context transition; a reconnect to the same context keeps it.
    func enableManually() {
        guard isShipDisconnected else { return }
        apply(shipContext.enableManually()
              ?? DeckUpdate(enabled: true, shipName: shipName, resetKeys: false))
    }

    /// Reset Deck, also applied after `vehicleDestroyed`: keys back to their defaults, self-destruct disarmed.
    /// Local only; sends nothing to the game.
    func resetDeck() {
        lit = Self.defaultLit
        selfDestructArmed = false
    }
}
