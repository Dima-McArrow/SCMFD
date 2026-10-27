import Foundation
import Testing
@testable import SCMFD

struct SessionActivityTests {
    private let server = UUID()
    private let stream = UUID()
    private let mission = UUID()
    private let at = Date(timeIntervalSince1970: 1_793_102_400)

    private func event(_ seq: Int64, kind: String = "reward", text: String = "Awarded 500 aUEC", amount: Int64? = 500, currency: String? = "aUEC", missionId: UUID? = nil, objective: String? = nil) -> SessionActivityEvent {
        SessionActivityEvent(seq: seq, kind: kind, at: at, text: text, missionId: missionId,
                             objectiveId: objective, amount: amount, currency: currency)
    }

    private func page(_ events: [SessionActivityEvent], streamId: UUID? = nil, first: Int64 = 1, latest: Int64? = nil, ended: Bool = false) -> ServerActivityPage {
        ServerActivityPage(sessionId: server, streamId: streamId ?? stream, startedAt: at,
                           firstSeq: first, latestSeq: latest ?? events.last?.seq ?? 0, ended: ended, events: events)
    }

    @Test func reconnectReplayDoesNotDoubleCountAndCurrenciesStaySeparate() {
        let store = SessionActivityStore(fileURL: nil)
        let first = page([event(1), event(2, amount: 1000, currency: "UEC")])
        store.receive(first)
        store.setConnected(false)
        store.receive(first)
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].rewards["aUEC"] == 500)
        #expect(store.sessions[0].rewards["UEC"] == 1000)
        #expect(store.sessions[0].rewardCount == 2)
    }

    @Test func replayGapIsVisibleInsteadOfClaimingACompleteTotal() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([event(1)]))
        store.receive(page([event(45)], first: 45))
        #expect(store.sessions[0].incomplete)
        #expect(store.sessions[0].rewards["aUEC"] == 1000)
    }

    @Test func newTrackingSessionStartsAtZeroAndIgnoresPreBoundaryReplay() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([event(1)]))
        store.startNewSession(at: at.addingTimeInterval(10))
        store.receive(page([event(1), event(2)]))
        #expect(store.sessions.count == 2)
        #expect(store.sessions[0].rewards["aUEC"] == 500)
        #expect(store.sessions[1].rewards["aUEC"] == 500)
        #expect(store.sessions[1].ended)
    }

    @Test func cannotResetWhileCatchingUpOrDisconnected() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([event(1)], latest: 4))
        store.startNewSession()
        #expect(store.sessions.count == 1)
        store.receive(page([event(2), event(3), event(4)]))
        store.setConnected(false)
        store.startNewSession()
        #expect(store.sessions.count == 1)
    }

    @Test func contractsUseMissionAndObjectiveIdentityAndRetainTerminalStatus() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([
            event(1, kind: "contractAccepted", text: "Haul cargo", amount: nil, currency: nil, missionId: mission),
            event(2, kind: "newObjective", text: "Deliver 32 SCU", amount: nil, currency: nil, missionId: mission, objective: "dropoff_1"),
            event(3, kind: "objectiveComplete", text: "Delivered cargo", amount: nil, currency: nil, missionId: mission, objective: "dropoff_1"),
            event(4, kind: "contractComplete", text: "Haul cargo", amount: nil, currency: nil, missionId: mission),
        ]))
        store.receive(page([event(5, kind: "contractAccepted", text: "Haul cargo", amount: nil, currency: nil, missionId: mission)]))
        let contract = store.sessions[0].contracts[0]
        #expect(store.sessions[0].contracts.count == 1)
        #expect(contract.status == "contractComplete")
        #expect(contract.objectives.count == 1)
        #expect(contract.objectives[0].completed)
        #expect(store.sessions[0].rewards.isEmpty)
    }

    @Test func rewardWithNoMissionDoesNotAttachToTheNearestContract() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([
            event(1, kind: "contractComplete", text: "Haul cargo", amount: nil, currency: nil, missionId: mission),
            event(2),
        ]))
        #expect(store.sessions[0].contracts.count == 1)
        #expect(store.sessions[0].rewards["aUEC"] == 500)
        #expect(store.sessions[0].recentEvents.first?.missionId == nil)
    }

    @Test func generationChangeArchivesPriorSessionAndStartsNewCapture() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([event(1)]))
        store.receive(page([], streamId: UUID()))
        #expect(store.sessions.count == 2)
        #expect(store.sessions[0].rewards.isEmpty)
        #expect(store.sessions[1].ended)
        #expect(store.sessions[1].rewards["aUEC"] == 500)
        #expect(store.sessions[1].incomplete)
    }

    @Test func sessionEndPreservesTotalsAndHistory() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([event(1), event(2, kind: "sessionEnded", text: "", amount: nil, currency: nil)], ended: true))
        #expect(store.sessions[0].ended)
        #expect(store.sessions[0].rewards["aUEC"] == 500)
    }

    @Test func historySurvivesStoreReloadWithoutReplayDoubleCounting() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "csmfd-activity-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "history.json")
        let store = SessionActivityStore(fileURL: url)
        let first = page([event(1)])
        store.receive(first)
        let restored = SessionActivityStore(fileURL: url)
        restored.receive(first)
        #expect(!restored.storageFailed)
        #expect(restored.sessions[0].rewards["aUEC"] == 500)
    }

    @Test func malformedHistoryIsPreservedRatherThanOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "csmfd-activity-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "history.json")
        let original = Data("unreadable history".utf8)
        try original.write(to: url)
        let store = SessionActivityStore(fileURL: url)
        store.receive(page([event(1)]))
        #expect(store.storageFailed)
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func invalidMoneyAndInvalidPageOrderingAreRejected() {
        #expect(!page([event(1, amount: -500)]).isValid)
        #expect(!page([event(2), event(1)]).isValid)
        #expect(!page([event(1, currency: "credits")]).isValid)
        #expect(!page([event(1, kind: "contractComplete", amount: nil, currency: nil)]).isValid)
    }

    @Test func rollingRecentListDoesNotReduceSessionRewardTotal() {
        let store = SessionActivityStore(fileURL: nil)
        for seq in Int64(1)...Int64(300) { store.receive(page([event(seq)])) }
        #expect(store.sessions[0].recentEvents.count == 128)
        #expect(store.sessions[0].rewardCount == 300)
        #expect(store.sessions[0].rewards["aUEC"] == 150_000)
    }

    @Test func activityWireMessageDecodesAndRequiresTheWelcomedSession() throws {
        let json = #"""
        {"v":2,"type":"activity","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900",
        "streamId":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","startedAt":"2026-10-27T12:00:00.000Z",
        "firstSeq":1,"latestSeq":1,"ended":false,
        "events":[{"seq":1,"kind":"reward","at":"2026-10-27T12:00:01.000Z","text":"Awarded 500 aUEC:","amount":500,"currency":"aUEC"}]}
        """#
        guard case .activity(let decoded) = try ProtocolV2.decode(Data(json.utf8)) else {
            Issue.record("Expected activity"); return
        }
        #expect(decoded.isValid)
        var session = ServerSession(configuration: SessionConfiguration(appVersion: "test", deviceName: "test"), serverId: nil, token: nil)
        let effects = session.receive(.activity(decoded), at: .now)
        #expect(effects.contains { if case .close = $0 { true } else { false } })

        var ready = ServerSession(configuration: SessionConfiguration(appVersion: "test", deviceName: "test"), serverId: nil, token: nil)
        _ = ready.transportOpened(at: .now)
        _ = ready.receive(.welcome(ServerWelcome(server: "test", serverVersion: "1", serverId: UUID(), sessionId: decoded.sessionId,
                                                connectionId: UUID(), chatKey: "enter")), at: .now)
        #expect(ready.receive(.activity(decoded), at: .now) == [.activity(decoded)])
        let wrongSession = page([event(1)])
        let wrongEffects = ready.receive(.activity(wrongSession), at: .now)
        #expect(wrongEffects.contains { if case .close = $0 { true } else { false } })
    }
}
