import Foundation
import Testing
@testable import SCMFD

struct PartyStateTests {
    private let session = UUID()
    private let stream = UUID()
    private let generation = UUID()
    private let at = Date(timeIntervalSince1970: 1_793_102_400)

    private func event(_ seq: Int64, _ kind: String, _ text: String = "") -> SessionActivityEvent {
        SessionActivityEvent(seq: seq, kind: kind, at: at, text: text, missionId: nil,
                             objectiveId: nil, amount: nil, currency: nil)
    }

    private func page(_ events: [SessionActivityEvent], streamId: UUID? = nil, first: Int64 = 1,
                      latest: Int64? = nil, ended: Bool = false) -> ServerActivityPage {
        ServerActivityPage(sessionId: session, streamId: streamId ?? stream, startedAt: at,
                           firstSeq: first, latestSeq: latest ?? events.last?.seq ?? 0, ended: ended, events: events)
    }

    private func snapshot(_ status: LogStatus.Status = .ready, generation: UUID? = nil, running: Bool = true) -> ServerState {
        ServerState(sessionId: session, seq: 1, partial: true,
                    game: .value(GameStatus(running: running, focused: false, build: nil)),
                    log: .value(LogStatus(status: status, generation: generation ?? self.generation, observedAt: nil)),
                    ship: .absent, shipContext: .absent, qtTarget: .absent, hangarRequest: .absent)
    }

    @Test func membershipLeaderRemovalAndDisbandFollowOnlyObservedEvents() {
        var state = PartyState()
        state.receive(page([event(1, "partyJoined"), event(2, "partyMemberJoined", "Pilot_One"),
                            event(3, "partyLeaderChanged", "Pilot_One")]))
        #expect(state.membership == .observed)
        #expect(state.members == ["Pilot_One"])
        #expect(state.leader == "Pilot_One")
        state.receive(page([event(4, "partyMemberLeft", "Pilot_One")]))
        #expect(state.members.isEmpty)
        #expect(state.leader == nil)
        #expect(state.membership == .observed)
        state.receive(page([event(5, "partyDisbanded")]))
        #expect(state.membership == .disbanded)
        state.receive(page([event(6, "partyCreated")]))
        #expect(state.membership == .observed)
        #expect(state.members.isEmpty)
        #expect(state.leader == nil)
    }

    @Test func replayDoesNotDuplicateAndUnrelatedEventsStillAdvanceTheCursor() {
        var state = PartyState()
        let first = page([event(1, "partyMemberJoined", "Pilot_One"), event(2, "futureObservation")])
        state.receive(first)
        state.receive(first)
        state.receive(page([event(3, "partyMemberJoined", "Pilot_One")]))
        #expect(state.members == ["Pilot_One"])
        #expect(state.history.count == 2)
        #expect(state.lastSeq == 3)
        #expect(!state.hasGap)
    }

    @Test func replayGapDropsOldRosterAndLeaderInsteadOfClaimingContinuity() {
        var state = PartyState()
        state.receive(page([event(1, "partyLeaderChanged", "Pilot_One")]))
        state.receive(page([event(45, "partyMemberJoined", "Pilot_Two")], first: 45))
        #expect(state.hasGap)
        #expect(state.leader == nil)
        #expect(state.members == ["Pilot_Two"])
        #expect(state.history.count == 2)
    }

    @Test func newStreamNeverRestoresThePreviousRoster() {
        var state = PartyState()
        state.receive(page([event(1, "partyLeaderChanged", "Pilot_One")]))
        state.receive(page([], streamId: UUID()))
        #expect(state.members.isEmpty)
        #expect(state.leader == nil)
        #expect(state.membership == .unknown)
        #expect(state.history.isEmpty)
    }

    @Test func malformedPartyNameIsSkippedWithoutRejectingTheSharedPage() {
        var state = PartyState()
        let malformed = page([event(1, "partyMemberJoined", ""), event(2, "partyLeaderChanged", "Pilot_Two")])
        #expect(malformed.isValid)
        state.receive(malformed)
        #expect(state.members == ["Pilot_Two"])
        #expect(state.history.count == 1)
        #expect(state.hasGap)
        #expect(!event(1, "partyMemberJoined", String(repeating: "x", count: 97)).isUsablePartyObservation)
        #expect(!event(1, "partyMemberJoined", "bad\u{FFFD}name").isUsablePartyObservation)
    }

    @Test func disconnectStaysStaleUntilAllReplayPagesArrive() {
        let store = PartyStore()
        store.receiveState(snapshot())
        store.setConnected(true)
        store.receive(page([event(1, "partyMemberJoined", "Pilot_One")]))
        #expect(!store.isStale)
        store.setConnected(false)
        #expect(store.isStale)
        #expect(store.state.members == ["Pilot_One"])
        store.setConnected(true)
        store.receive(page([event(1, "partyMemberJoined", "Pilot_One")], latest: 2))
        #expect(store.isStale)
        store.receive(page([event(2, "partyMemberJoined", "Pilot_Two")]))
        #expect(!store.isStale)
        #expect(store.state.history.count == 2)
    }

    @Test func sourceLossGameEndAndLogResetAreVisibleWithoutShipOrThemeDependencies() {
        let store = PartyStore()
        store.receiveState(snapshot())
        store.setConnected(true)
        store.receive(page([event(1, "partyLeaderChanged", "Pilot_One")]))
        store.receiveState(snapshot(.catchingUp))
        #expect(store.isStale)
        #expect(store.state.leader == "Pilot_One")
        store.receiveState(snapshot())
        #expect(!store.isStale)
        store.receiveState(snapshot(.catchingUp))
        store.receiveState(snapshot(.unreadable))
        #expect(store.isStale)
        #expect(store.state.leader == nil)
        store.receiveState(snapshot(generation: UUID()))
        #expect(store.state.membership == .unknown)
        store.receive(page([event(1, "partyJoined")], streamId: UUID()))
        store.receive(page([event(2, "sessionEnded")], streamId: store.state.streamId, ended: true))
        #expect(store.isStale)
    }

    @Test func partyDoesNotChangeRewardTotalsOrMarkFinanceIncomplete() {
        let store = SessionActivityStore(fileURL: nil)
        var reward = event(2, "reward", "Awarded 500 aUEC:")
        reward = SessionActivityEvent(seq: reward.seq, kind: reward.kind, at: at, text: reward.text,
                                      missionId: nil, objectiveId: nil, amount: 500, currency: "aUEC")
        store.receive(page([event(1, "partyJoined"), reward, event(3, "partyMemberJoined", "Pilot_One")]))
        #expect(store.sessions[0].rewards["aUEC"] == 500)
        #expect(store.sessions[0].rewardCount == 1)
        #expect(!store.sessions[0].incomplete)
        #expect(store.sessions[0].recentEvents.count == 1)
        #expect(store.sessions[0].lastSeq == 3)
    }

    @Test func historyAndNamesHaveIndependentBounds() {
        var state = PartyState()
        for seq in Int64(1)...Int64(200) {
            state.receive(page([event(seq, "partyMemberJoined", "Pilot_\(seq)")]))
        }
        #expect(state.members.count == 64)
        #expect(state.history.count == 128)
        #expect(state.hasGap)
    }

    // Exactly the BE server-activity-party.json fixture; this also exercises mixed reward/Party pages.
    nonisolated static let partyFixture = #"{"v":2,"type":"activity","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","streamId":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","startedAt":"2026-10-27T12:00:00.000Z","firstSeq":1,"latestSeq":4,"ended":false,"events":[{"seq":1,"kind":"partyJoined","at":"2026-10-27T12:00:01.000Z","text":""},{"seq":2,"kind":"partyMemberJoined","at":"2026-10-27T12:00:02.000Z","text":"Pilot_One"},{"seq":3,"kind":"partyLeaderChanged","at":"2026-10-27T12:00:03.000Z","text":"Pilot_One"},{"seq":4,"kind":"reward","at":"2026-10-27T12:00:04.000Z","text":"Awarded 500 aUEC:","amount":500,"currency":"aUEC"}]}"#

    @Test func sharedWireFixtureDecodesAndPassesTheAuthenticatedSession() throws {
        guard case .activity(let decoded) = try ProtocolV2.decode(Data(Self.partyFixture.utf8)) else {
            Issue.record("Expected activity"); return
        }
        #expect(decoded.isValid)
        let start = Date(timeIntervalSince1970: 1_793_102_400)
        #expect(decoded.sessionId == UUID(uuidString: "7a42291e-21db-4ac5-a3e1-ea278bb54900"))
        #expect(decoded.streamId == UUID(uuidString: "982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1"))
        #expect(decoded.startedAt == start)
        #expect(decoded.firstSeq == 1 && decoded.latestSeq == 4 && !decoded.ended)
        #expect(decoded.events == [
            SessionActivityEvent(seq: 1, kind: "partyJoined", at: start.addingTimeInterval(1), text: "",
                                 missionId: nil, objectiveId: nil, amount: nil, currency: nil),
            SessionActivityEvent(seq: 2, kind: "partyMemberJoined", at: start.addingTimeInterval(2), text: "Pilot_One",
                                 missionId: nil, objectiveId: nil, amount: nil, currency: nil),
            SessionActivityEvent(seq: 3, kind: "partyLeaderChanged", at: start.addingTimeInterval(3), text: "Pilot_One",
                                 missionId: nil, objectiveId: nil, amount: nil, currency: nil),
            SessionActivityEvent(seq: 4, kind: "reward", at: start.addingTimeInterval(4), text: "Awarded 500 aUEC:",
                                 missionId: nil, objectiveId: nil, amount: 500, currency: "aUEC"),
        ])
        var ready = ServerSession(configuration: SessionConfiguration(appVersion: "test", deviceName: "test"), serverId: nil, token: nil)
        _ = ready.transportOpened(at: .now)
        _ = ready.receive(.welcome(ServerWelcome(server: "test", serverVersion: "1", serverId: UUID(), sessionId: decoded.sessionId,
                                                connectionId: UUID(), chatKey: "enter")), at: .now)
        #expect(ready.receive(.activity(decoded), at: .now) == [.activity(decoded)])
        let store = PartyStore()
        store.receive(decoded)
        #expect(store.state.members == ["Pilot_One"])
        #expect(store.state.history.count == 3)
    }
}
