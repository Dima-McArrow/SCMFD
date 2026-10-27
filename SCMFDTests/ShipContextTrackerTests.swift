import Foundation
import Testing
@testable import SCMFD

/// FIX-02 acceptance rows (41.9, 41.17): how merged server snapshots drive the Deck.
struct ShipContextTrackerTests {
    static let sessionId = UUID(uuidString: "7a42291e-21db-4ac5-a3e1-ea278bb54900")!
    static let connectionId = UUID(uuidString: "a42a3cd9-a193-457b-b2dd-a973e3d9b35a")!
    static let rambler = "Drake Cutter Rambler"

    private let observedAt = Date(timeIntervalSince1970: 1_800_000_000)

    /// A merged snapshot, as `ServerSession` emits it.
    private func snapshot(
        revision: Int,
        status: ShipContextStatus.Status,
        ship: String?,
        model: String? = nil,
        sessionId: UUID = sessionId
    ) -> ServerState {
        let reason: ShipContextStatus.Reason = switch status {
        case .assumed: .channelJoined
        case .noShip: .clearDriver
        case .unknown: .startup
        }
        return ServerState(
            sessionId: sessionId, seq: revision + 1, partial: false,
            game: .value(GameStatus(running: true, focused: true, build: nil)),
            log: .value(LogStatus(status: .ready, generation: UUID(), observedAt: nil)),
            ship: .value(ship.map {
                ShipStatus(name: $0, model: model, entityId: nil, manufacturerPrefix: "DRAK",
                           confidence: .assumed, observedAt: observedAt)
            }),
            shipContext: .value(ShipContextStatus(revision: revision, status: status, reason: reason,
                                                  contextId: nil, manufacturerPrefix: "DRAK", observedAt: nil)),
            qtTarget: .value(QuantumTargetStatus(mode: .unknown, internalName: nil, displayName: nil,
                                                 confidence: .stale, observedAt: nil)),
            hangarRequest: .value(HangarRequestState(status: .idle, commandId: nil, contextId: nil,
                                                     since: nil, updatedAt: nil))
        )
    }

    /// A tracker that has applied a joined ship at revision 3.
    private func joined() -> ShipContextTracker {
        var tracker = ShipContextTracker()
        _ = tracker.receive(snapshot(revision: 3, status: .assumed, ship: Self.rambler), connectionId: Self.connectionId)
        return tracker
    }

    /// A tracker after ClearDriver at revision 4, with the Deck enabled manually.
    private func clearedAndEnabledManually() -> ShipContextTracker {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, status: .noShip, ship: nil), connectionId: Self.connectionId)
        _ = tracker.enableManually()
        return tracker
    }

    @Test func fullAssumedStateEnablesTheDeckAndResetsOnce() {
        var tracker = ShipContextTracker()
        let state = snapshot(revision: 3, status: .assumed, ship: Self.rambler)
        let first = tracker.receive(state, connectionId: Self.connectionId)
        #expect(first == DeckUpdate(enabled: true, shipName: Self.rambler, resetLocalState: true))
        #expect(tracker.receive(state, connectionId: Self.connectionId)?.resetLocalState == false)
    }

    @Test func unrelatedDeltaKeepsTheLights() {
        var tracker = joined()
        // A qtTarget-only delta merges into a snapshot with the same ship context.
        let update = tracker.receive(snapshot(revision: 3, status: .assumed, ship: Self.rambler),
                                     connectionId: Self.connectionId)
        #expect(update == DeckUpdate(enabled: true, shipName: Self.rambler, resetLocalState: false))
    }

    @Test func enrichedShipUpdatesTheLabelWithoutReset() {
        var tracker = joined()
        let enriched = snapshot(revision: 3, status: .assumed, ship: "Drake Cutter Rambler (enriched)",
                                model: "DRAK_Cutter_Rambler")
        let update = tracker.receive(enriched, connectionId: Self.connectionId)
        #expect(update == DeckUpdate(enabled: true, shipName: "Drake Cutter Rambler (enriched)",
                                     resetLocalState: false))
    }

    @Test func clearDriverDisablesTheDeckAndResetsLocalState() {
        var tracker = joined()
        let update = tracker.receive(snapshot(revision: 4, status: .noShip, ship: nil), connectionId: Self.connectionId)
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetLocalState: true))
    }

    @Test func manualEnableSurvivesAnIdenticalSnapshot() {
        var tracker = clearedAndEnabledManually()
        let update = tracker.receive(snapshot(revision: 4, status: .noShip, ship: nil), connectionId: Self.connectionId)
        #expect(update?.enabled == true)
        #expect(update?.resetLocalState == false)
    }

    @Test func newClearDriverDropsTheManualEnable() {
        var tracker = clearedAndEnabledManually()
        let update = tracker.receive(snapshot(revision: 5, status: .noShip, ship: nil), connectionId: Self.connectionId)
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetLocalState: true))
    }

    @Test func reconnectDropsTheManualEnableWithoutReset() {
        var tracker = clearedAndEnabledManually()
        let update = tracker.receive(snapshot(revision: 4, status: .noShip, ship: nil), connectionId: UUID())
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetLocalState: false))
    }

    @Test func newServerSessionWithTheSameRevisionIsATransition() {
        var tracker = joined()
        let restarted = snapshot(revision: 3, status: .assumed, ship: Self.rambler, sessionId: UUID())
        #expect(tracker.receive(restarted, connectionId: Self.connectionId)?.resetLocalState == true)
    }

    @Test func clearDriverWhileTheChannelStaysActiveKeepsTheDeckOff() {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, status: .noShip, ship: nil), connectionId: Self.connectionId)
        // Later deltas without a new join keep revision 4.
        let later = tracker.receive(snapshot(revision: 4, status: .noShip, ship: nil), connectionId: Self.connectionId)
        #expect(later == DeckUpdate(enabled: false, shipName: nil, resetLocalState: false))
    }

    @Test func serverStartedMidFlightNeedsAManualEnable() {
        var tracker = ShipContextTracker()
        let update = tracker.receive(snapshot(revision: 0, status: .unknown, ship: nil), connectionId: Self.connectionId)
        #expect(update?.enabled == false)
        #expect(tracker.enableManually()?.enabled == true)
    }

    @Test func manualEnableWithoutServerContextIsLeftToTheCaller() {
        var tracker = ShipContextTracker()
        #expect(tracker.enableManually() == nil)
    }
}
