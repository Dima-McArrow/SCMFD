import Foundation
import Testing
@testable import SCMFD

/// FIX-07 table (41.23): how merged server snapshots drive the Deck, the auto theme and the keys.
struct ShipContextTrackerTests {
    static let sessionId = UUID(uuidString: "7a42291e-21db-4ac5-a3e1-ea278bb54900")!
    static let rambler = "Drake Cutter Rambler"

    private let observedAt = Date(timeIntervalSince1970: 1_800_000_000)

    /// A merged snapshot, as `ServerSession` emits it. `status` follows `reason` unless given.
    private func snapshot(
        revision: Int,
        reason: ShipContextStatus.Reason,
        rawReason: String? = nil,
        status: ShipContextStatus.Status? = nil,
        ship: String?,
        model: String? = nil,
        sessionId: UUID = sessionId,
        qtTarget: QuantumTargetStatus = QuantumTargetStatus(mode: .unknown, internalName: nil, displayName: nil,
                                                            confidence: .stale, observedAt: nil),
        hangar: HangarRequestStatus = .idle,
        contextPrefix: String? = "DRAK",
        shipPrefix: String? = "DRAK"
    ) -> ServerState {
        let statusForReason: ShipContextStatus.Status = switch reason {
        case .channelJoined: .assumed
        case .startup, .unknown: .unknown
        case .clearDriver, .channelLeft, .vehicleDestroyed, .gameEnded, .logReset: .noShip
        }
        let status = status ?? statusForReason
        return ServerState(
            sessionId: sessionId, seq: revision + 1, partial: false,
            game: .value(GameStatus(running: true, focused: true, build: nil)),
            log: .value(LogStatus(status: .ready, generation: UUID(), observedAt: nil)),
            ship: .value(ship.map {
                ShipStatus(name: $0, model: model, entityId: nil, manufacturerPrefix: shipPrefix,
                           confidence: .assumed, observedAt: observedAt)
            }),
            shipContext: .value(ShipContextStatus(revision: revision, status: status,
                                                  reason: rawReason ?? reason.rawValue, contextId: nil,
                                                  manufacturerPrefix: contextPrefix, observedAt: nil)),
            qtTarget: .value(qtTarget),
            hangarRequest: .value(HangarRequestState(status: hangar, commandId: nil, contextId: nil,
                                                     since: nil, updatedAt: nil))
        )
    }

    private func delta(_ json: String) throws -> ServerState {
        guard case .state(let state) = try ProtocolV2.decode(Data(json.utf8)) else {
            Issue.record("Expected a state message")
            throw CancellationError()
        }
        return state
    }

    private func theme(_ theme: AppTheme, revision: Int, sessionId: UUID = sessionId) -> ThemeChange {
        ThemeChange(theme: theme, sessionId: sessionId, revision: revision)
    }

    /// A tracker that has applied a joined Drake at revision 3.
    private func joined() -> ShipContextTracker {
        var tracker = ShipContextTracker()
        _ = tracker.receive(snapshot(revision: 3, reason: .channelJoined, ship: Self.rambler))
        return tracker
    }

    /// A tracker after a channel leave at revision 4, with the Deck enabled manually.
    private func leftAndEnabledManually() -> ShipContextTracker {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        _ = tracker.enableManually()
        return tracker
    }

    // MARK: - channelJoined

    /// `server-state-full.json`: channelJoined DRAK.
    @Test func fullJoinedSnapshotEnablesTheDeckWithTheManufacturerTheme() throws {
        var tracker = ShipContextTracker()
        let state = try delta(ProtocolV2Tests.fullState)
        #expect(tracker.receive(state) == DeckUpdate(enabled: true, shipName: Self.rambler, resetKeys: false,
                                                     hangarRequest: .idle, theme: theme(.manufacturer(.drake), revision: 3)))
        // The same snapshot again is not a transition.
        #expect(tracker.receive(state) == DeckUpdate(enabled: true, shipName: Self.rambler, resetKeys: false,
                                                     hangarRequest: .idle))
    }

    @Test func unrelatedDeltaChangesNothing() {
        var tracker = joined()
        // A qtTarget-only delta merges into a snapshot with the same ship context.
        let update = tracker.receive(snapshot(revision: 3, reason: .channelJoined, ship: Self.rambler))
        #expect(update == DeckUpdate(enabled: true, shipName: Self.rambler, resetKeys: false, hangarRequest: .idle))
    }

    @Test func enrichedShipUpdatesOnlyTheLabel() {
        var tracker = joined()
        let enriched = snapshot(revision: 3, reason: .channelJoined, ship: "Drake Cutter Rambler (enriched)",
                                model: "DRAK_Cutter_Rambler")
        #expect(tracker.receive(enriched) == DeckUpdate(enabled: true, shipName: "Drake Cutter Rambler (enriched)",
                                                        resetKeys: false, hangarRequest: .idle))
    }

    @Test func channelJoinUsesTheContextPrefix() {
        var tracker = ShipContextTracker()
        let update = tracker.receive(snapshot(revision: 3, reason: .channelJoined, ship: "Aegis Gladius",
                                              contextPrefix: "AEGS", shipPrefix: "AEGS"))
        #expect(update?.theme == theme(.manufacturer(.aegis), revision: 3))
    }

    @Test func shipPrefixIsTheFallback() {
        var tracker = ShipContextTracker()
        let update = tracker.receive(snapshot(revision: 3, reason: .channelJoined, ship: "Aegis Gladius",
                                              contextPrefix: nil, shipPrefix: "AEGS"))
        #expect(update?.theme?.theme == .manufacturer(.aegis))
    }

    @Test func unknownPrefixEnablesTheDeckButKeepsTheTheme() {
        var tracker = ShipContextTracker()
        let update = tracker.receive(snapshot(revision: 3, reason: .channelJoined, ship: "Mystery",
                                              contextPrefix: "FOO", shipPrefix: "FOO"))
        #expect(update == DeckUpdate(enabled: true, shipName: "Mystery", resetKeys: false, hangarRequest: .idle))
    }

    @Test func sameRevisionWithAnotherPrefixIsNotAThemeChange() {
        var tracker = joined()
        let enriched = snapshot(revision: 3, reason: .channelJoined, ship: Self.rambler, contextPrefix: "AEGS",
                                shipPrefix: "AEGS")
        #expect(tracker.receive(enriched)?.theme == nil)
    }

    @Test func joinOfAnotherShipAfterALeaveSwitchesTheThemeAndKeepsTheKeys() {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        let update = tracker.receive(snapshot(revision: 5, reason: .channelJoined, ship: "Anvil C8R Pisces Rescue",
                                              contextPrefix: "ANVL", shipPrefix: "ANVL"))
        #expect(update == DeckUpdate(enabled: true, shipName: "Anvil C8R Pisces Rescue", resetKeys: false,
                                     hangarRequest: .idle, theme: theme(.manufacturer(.anvil), revision: 5)))
    }

    /// A manual pick between two Drake joins must be overridden by the second one.
    @Test func twoJoinsOfTheSameManufacturerAreTwoThemeChanges() {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        let second = tracker.receive(snapshot(revision: 5, reason: .channelJoined, ship: Self.rambler))
        #expect(second?.theme == theme(.manufacturer(.drake), revision: 5))
        #expect(second?.theme != theme(.manufacturer(.drake), revision: 3))
    }

    // MARK: - Leaving the ship

    @Test(arguments: [ShipContextStatus.Reason.channelLeft, .gameEnded, .logReset])
    func leavingDisablesTheDeckWithTheStandardThemeAndKeepsTheKeys(reason: ShipContextStatus.Reason) {
        var tracker = joined()
        let update = tracker.receive(snapshot(revision: 4, reason: reason, ship: nil))
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetKeys: false, hangarRequest: .idle,
                                     theme: theme(.standard, revision: 4)))
    }

    @Test func laterDeltasAfterALeaveKeepTheDeckOff() {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        let later = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        #expect(later == DeckUpdate(enabled: false, shipName: nil, resetKeys: false, hangarRequest: .idle))
    }

    /// `server-state-delta-vehicle-destroyed.json`, merged onto a joined snapshot with a target and a pending request.
    @Test func vehicleDestroyedFixtureDisablesTheDeckAndResetsTheKeys() throws {
        let before = snapshot(revision: 4, reason: .channelJoined, ship: Self.rambler,
                              qtTarget: QuantumTargetStatus(mode: .destination, internalName: "OOC_Stanton_1_Hurston",
                                                            displayName: nil, confidence: .confirmed, observedAt: nil),
                              hangar: .pending)
        var tracker = ShipContextTracker()
        _ = tracker.receive(before)
        let update = tracker.receive(before.merged(with: try delta(ProtocolV2Tests.vehicleDestroyedDelta)))
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetKeys: true, quantumTarget: .unknown,
                                     hangarRequest: .idle, theme: theme(.standard, revision: 5)))
    }

    // MARK: - clearDriver (servers before 41.23)

    /// The Deck, the theme and the keys ignore it; the readouts still mirror the server.
    @Test func clearDriverFixtureChangesNothing() throws {
        let before = snapshot(revision: 3, reason: .channelJoined, ship: Self.rambler,
                              qtTarget: QuantumTargetStatus(mode: .destination, internalName: "OOC_Stanton_1_Hurston",
                                                            displayName: nil, confidence: .confirmed, observedAt: nil),
                              hangar: .pending)
        var tracker = ShipContextTracker()
        _ = tracker.receive(before)
        let update = tracker.receive(before.merged(with: try delta(ProtocolV2Tests.clearDriverDelta)))
        #expect(update == DeckUpdate(enabled: true, shipName: nil, resetKeys: false, quantumTarget: .unknown,
                                     hangarRequest: .idle))
    }

    @Test func clearDriverKeepsTheDeckOff() {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        let update = tracker.receive(snapshot(revision: 5, reason: .clearDriver, ship: nil))
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetKeys: false, hangarRequest: .idle))
    }

    @Test func clearDriverKeepsAManualEnable() {
        var tracker = leftAndEnabledManually()
        #expect(tracker.receive(snapshot(revision: 5, reason: .clearDriver, ship: nil))?.enabled == true)
        // Still on for the same revision, and the next real transition decides again.
        #expect(tracker.receive(snapshot(revision: 5, reason: .clearDriver, ship: nil))?.enabled == true)
        #expect(tracker.receive(snapshot(revision: 6, reason: .gameEnded, ship: nil))?.enabled == false)
    }

    @Test func clearDriverAsTheFirstContextLeavesTheDeckOff() {
        var tracker = ShipContextTracker()
        let update = tracker.receive(snapshot(revision: 4, reason: .clearDriver, ship: nil))
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetKeys: false, hangarRequest: .idle))
    }

    // MARK: - Manual enable

    @Test func manualEnableSurvivesASameRevisionDelta() {
        var tracker = leftAndEnabledManually()
        let update = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        #expect(update == DeckUpdate(enabled: true, shipName: nil, resetKeys: false, hangarRequest: .idle))
    }

    /// Was `reconnectDropsTheManualEnableWithoutReset`: FIX-07 keeps the enable across a reconnect, because the
    /// new connection's full snapshot carries the same context.
    @Test func manualEnableSurvivesAReconnect() {
        var tracker = leftAndEnabledManually()
        tracker.connectionLost()
        let update = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        #expect(update == DeckUpdate(enabled: true, shipName: nil, resetKeys: false, hangarRequest: .idle))
    }

    @Test func nextTransitionEndsTheManualEnable() {
        var tracker = leftAndEnabledManually()
        let update = tracker.receive(snapshot(revision: 5, reason: .gameEnded, ship: nil))
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetKeys: false, hangarRequest: .idle,
                                     theme: theme(.standard, revision: 5)))
    }

    @Test func newServerSessionWithTheSameRevisionEndsTheManualEnable() {
        var tracker = leftAndEnabledManually()
        let restarted = UUID()
        let update = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil, sessionId: restarted))
        #expect(update?.enabled == false)
        #expect(update?.theme == theme(.standard, revision: 4, sessionId: restarted))
    }

    @Test func manualEnableKeepsTheKeysAndTheTheme() {
        var tracker = joined()
        _ = tracker.receive(snapshot(revision: 4, reason: .channelLeft, ship: nil))
        #expect(tracker.enableManually() == DeckUpdate(enabled: true, shipName: nil, resetKeys: false,
                                                       hangarRequest: .idle))
    }

    @Test func serverStartedMidFlightNeedsAManualEnable() {
        var tracker = ShipContextTracker()
        let update = tracker.receive(snapshot(revision: 0, reason: .startup, ship: nil))
        #expect(update == DeckUpdate(enabled: false, shipName: nil, resetKeys: false, hangarRequest: .idle))
        #expect(tracker.enableManually()?.enabled == true)
    }

    @Test func manualEnableWithoutServerContextIsLeftToTheCaller() {
        var tracker = ShipContextTracker()
        #expect(tracker.enableManually() == nil)
    }

    // MARK: - Unknown future reason

    @Test(arguments: [(ShipContextStatus.Status.assumed, true), (.noShip, false), (.unknown, false)])
    func unknownReasonFollowsTheStatusAndKeepsThemeAndKeys(status: ShipContextStatus.Status, enabled: Bool) {
        var tracker = joined()
        let update = tracker.receive(snapshot(revision: 6, reason: .unknown, rawReason: "somethingNew",
                                              status: status, ship: nil))
        #expect(update == DeckUpdate(enabled: enabled, shipName: nil, resetKeys: false, hangarRequest: .idle))
    }

    // MARK: - FIX-03: QT readout and ATC mirrored from state

    private func target(_ mode: QuantumTargetStatus.Mode, internal internalName: String?,
                        display: String?) -> QuantumTargetStatus {
        QuantumTargetStatus(mode: mode, internalName: internalName, displayName: display, confidence: .confirmed,
                            observedAt: observedAt)
    }

    @Test func unknownQuantumTargetStaysUnknown() {
        #expect(QuantumTarget(target(.unknown, internal: nil, display: nil)) == .unknown)
    }

    @Test func destinationWithOnlyInternalNameShowsItAsIs() {
        #expect(QuantumTarget(target(.destination, internal: "OOC_Stanton_1_Hurston", display: nil))
                == .destination("OOC_Stanton_1_Hurston"))
    }

    @Test func destinationPrefersDisplayName() {
        #expect(QuantumTarget(target(.destination, internal: "OOC_Stanton_1_Hurston", display: "Hurston"))
                == .destination("Hurston"))
    }

    @Test func freeModeMapsToFreeMode() {
        #expect(QuantumTarget(target(.freeMode, internal: nil, display: nil)) == .freeMode)
    }

    @Test(arguments: [HangarRequestStatus.idle, .pending, .answered, .timeout])
    func hangarStatusIsMirrored(status: HangarRequestStatus) {
        var tracker = ShipContextTracker()
        let state = snapshot(revision: 3, reason: .channelJoined, ship: Self.rambler, hangar: status)
        #expect(tracker.receive(state)?.hangarRequest == status)
    }

    @Test func noSnapshotMeansNoServerData() {
        #expect(DeckUpdate(enabled: true, shipName: nil, resetKeys: false).hangarRequest == nil)
        var tracker = ShipContextTracker()
        #expect(tracker.enableManually() == nil)
    }

    @Test func manualEnableKeepsTheMirroredReadouts() {
        var tracker = ShipContextTracker()
        let hurston = target(.destination, internal: "OOC_Stanton_1_Hurston", display: nil)
        _ = tracker.receive(snapshot(revision: 0, reason: .startup, ship: nil, qtTarget: hurston, hangar: .pending))
        let update = tracker.enableManually()
        #expect(update?.quantumTarget == .destination("OOC_Stanton_1_Hurston"))
        #expect(update?.hangarRequest == .pending)
    }

    // MARK: - Transport lost

    @Test func lostConnectionClearsReadoutsButKeepsTheDeck() {
        var tracker = ShipContextTracker()
        let hurston = target(.destination, internal: "OOC_Stanton_1_Hurston", display: nil)
        _ = tracker.receive(snapshot(revision: 0, reason: .startup, ship: nil, qtTarget: hurston, hangar: .pending))
        tracker.connectionLost()
        let update = tracker.enableManually()
        #expect(update?.enabled == true)
        #expect(update?.quantumTarget == .unknown)
        #expect(update?.hangarRequest == nil)
    }

    @Test func reconnectToTheSameContextIsNotAThemeChange() {
        var tracker = joined()
        tracker.connectionLost()
        let update = tracker.receive(snapshot(revision: 3, reason: .channelJoined, ship: Self.rambler))
        #expect(update == DeckUpdate(enabled: true, shipName: Self.rambler, resetKeys: false, hangarRequest: .idle))
    }
}
