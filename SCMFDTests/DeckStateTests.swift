import Foundation
import SwiftUI
import Testing
@testable import SCMFD

/// FIX-07 rows about the keys: what `DeckState` lights after server states and local actions.
struct DeckStateTests {
    private func state(_ json: String) throws -> ServerState {
        guard case .state(let state) = try ProtocolV2.decode(Data(json.utf8)) else {
            Issue.record("Expected a state message")
            throw CancellationError()
        }
        return state
    }

    /// A ship-context delta in the shape of the SCMFDBE fixtures.
    private func contextDelta(revision: Int, status: String, reason: String, prefix: String?) -> String {
        let prefixJSON = prefix.map { #""\#($0)""# } ?? "null"
        return #"{"v":2,"type":"state","sessionId":"\#(ProtocolV2Tests.sessionId)","seq":\#(revision + 10),"partial":true,"shipContext":{"revision":\#(revision),"status":"\#(status)","reason":"\#(reason)","contextId":null,"manufacturerPrefix":\#(prefixJSON),"observedAt":null}}"#
    }

    /// A Deck after `server-state-full.json` (Drake joined at revision 3), with two extra keys lit.
    private func joinedWithLights() throws -> (DeckState, ServerState) {
        let deck = DeckState()
        let full = try state(ProtocolV2Tests.fullState)
        deck.receive(full)
        deck.binding(for: .lights).wrappedValue = true
        deck.binding(for: .vtol).wrappedValue = true
        deck.selfDestructArmed = true
        return (deck, full)
    }

    /// FIX-07 first row: off at app start, in every mode, with landing gear and coupled mode lit.
    @Test func freshDeckIsOffWithLandingGearAndCoupledLit() {
        let deck = DeckState()
        #expect(deck.isShipDisconnected)
        #expect(deck.lit == [.landingGear, .coupledMode])
        #expect(!deck.selfDestructArmed)
    }

    @Test func tapsOnTheOffDeckAreIgnored() {
        let deck = DeckState()
        deck.binding(for: .lights).wrappedValue = true
        #expect(deck.lit == [.landingGear, .coupledMode])
    }

    @Test func firstAssumedChannelJoinedEnablesTheDeck() throws {
        let deck = DeckState()
        deck.receive(try state(ProtocolV2Tests.fullState))
        #expect(!deck.isShipDisconnected)
        #expect(deck.lit == [.landingGear, .coupledMode])
        #expect(deck.lastThemeChange?.theme == .manufacturer(.drake))
    }

    @Test func channelJoinedKeepsTheLitKeys() throws {
        let deck = DeckState()
        deck.enableManually()
        deck.binding(for: .lights).wrappedValue = true
        deck.receive(try state(ProtocolV2Tests.fullState))
        #expect(deck.lit == [.landingGear, .coupledMode, .lights])
        #expect(!deck.isShipDisconnected)
        #expect(deck.lastThemeChange?.theme == .manufacturer(.drake))
    }

    @Test func joinOfAnotherShipAfterALeaveKeepsTheKeysAndSwitchesTheTheme() throws {
        let (deck, full) = try joinedWithLights()
        let left = full.merged(with: try state(contextDelta(revision: 4, status: "noShip", reason: "channelLeft",
                                                            prefix: "DRAK")))
        deck.receive(left)
        #expect(deck.isShipDisconnected)
        #expect(deck.lastThemeChange?.theme == .standard)
        #expect(deck.lit == [.landingGear, .coupledMode, .lights, .vtol])

        deck.receive(left.merged(with: try state(contextDelta(revision: 5, status: "assumed", reason: "channelJoined",
                                                              prefix: "ANVL"))))
        #expect(!deck.isShipDisconnected)
        #expect(deck.lastThemeChange == ThemeChange(theme: .manufacturer(.anvil),
                                                    sessionId: full.sessionId, revision: 5))
        #expect(deck.lit == [.landingGear, .coupledMode, .lights, .vtol])
        #expect(deck.selfDestructArmed)
    }

    @Test func vehicleDestroyedFixtureResetsTheKeys() throws {
        let (deck, full) = try joinedWithLights()
        deck.binding(for: .landingGear).wrappedValue = false
        deck.binding(for: .coupledMode).wrappedValue = false
        #expect(!deck.lit.contains(.coupledMode))
        deck.receive(full.merged(with: try state(ProtocolV2Tests.vehicleDestroyedDelta)))
        #expect(deck.isShipDisconnected)
        #expect(deck.lastThemeChange?.theme == .standard)
        #expect(deck.lit == [.landingGear, .coupledMode])
        #expect(!deck.selfDestructArmed)
    }

    @Test func clearDriverFixtureChangesNothing() throws {
        let (deck, full) = try joinedWithLights()
        let theme = deck.lastThemeChange
        deck.receive(full.merged(with: try state(ProtocolV2Tests.clearDriverDelta)))
        #expect(!deck.isShipDisconnected)
        #expect(deck.lastThemeChange == theme)
        #expect(deck.lit == [.landingGear, .coupledMode, .lights, .vtol])
        #expect(deck.selfDestructArmed)
    }

    @Test func unknownReasonKeepsTheThemeAndTheKeys() throws {
        let (deck, full) = try joinedWithLights()
        let theme = deck.lastThemeChange
        deck.receive(full.merged(with: try state(contextDelta(revision: 6, status: "noShip", reason: "somethingNew",
                                                              prefix: nil))))
        #expect(deck.isShipDisconnected)
        #expect(deck.lastThemeChange == theme)
        #expect(deck.lit == [.landingGear, .coupledMode, .lights, .vtol])
    }

    @Test func manualEnableThenSameRevisionDeltaStaysOn() throws {
        let deck = DeckState()
        let full = try state(ProtocolV2Tests.fullState)
        let left = full.merged(with: try state(contextDelta(revision: 4, status: "noShip", reason: "channelLeft",
                                                            prefix: "DRAK")))
        deck.receive(left)
        deck.enableManually()
        #expect(!deck.isShipDisconnected)
        deck.receive(left)
        #expect(!deck.isShipDisconnected)
        // The next transition decides again.
        deck.receive(left.merged(with: try state(contextDelta(revision: 5, status: "noShip", reason: "gameEnded",
                                                              prefix: "DRAK"))))
        #expect(deck.isShipDisconnected)
    }

    /// Console link (no server context): Enable Deck uses the local fallback and keeps the keys.
    @Test func manualEnableWithoutAServerKeepsTheKeys() {
        let deck = DeckState()
        deck.enableManually()
        #expect(!deck.isShipDisconnected)
        #expect(deck.lit == [.landingGear, .coupledMode])
        deck.binding(for: .lights).wrappedValue = true
        #expect(deck.lit == [.landingGear, .coupledMode, .lights])
    }

    @Test func resetDeckLightsLandingGearAndCoupledAndDisarmsSelfDestruct() throws {
        let (deck, _) = try joinedWithLights()
        deck.binding(for: .landingGear).wrappedValue = false
        deck.binding(for: .coupledMode).wrappedValue = false
        #expect(!deck.lit.contains(.coupledMode))
        deck.resetDeck()
        #expect(deck.lit == [.landingGear, .coupledMode])
        #expect(!deck.selfDestructArmed)
    }

    @Test func lostConnectionKeepsTheDeckAndTheKeys() throws {
        let (deck, _) = try joinedWithLights()
        deck.connectionLost()
        #expect(!deck.isShipDisconnected)
        #expect(deck.lit == [.landingGear, .coupledMode, .lights, .vtol])
    }
}
