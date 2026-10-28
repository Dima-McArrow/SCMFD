import Foundation
import Testing
@testable import SCMFD

struct ShipChannelThemeTests {
    let stream = UUID()
    let session = UUID()
    let at = Date(timeIntervalSince1970: 1_800_000_000)
    let aurora = String(repeating: "a", count: 64)
    let redeemer = String(repeating: "b", count: 64)

    private func event(_ seq: Int64, _ kind: String, _ name: String, _ channel: String) -> SessionActivityEvent {
        SessionActivityEvent(seq: seq, kind: kind, at: at, text: name, missionId: nil,
                             objectiveId: nil, amount: nil, currency: nil, channelId: channel)
    }

    private func page(_ events: [SessionActivityEvent], latest: Int64? = nil) -> ServerActivityPage {
        ServerActivityPage(sessionId: session, streamId: stream, startedAt: at, firstSeq: 1,
                           latestSeq: latest ?? events.last?.seq ?? 0, ended: false, events: events)
    }

    @Test func joinSelectsManufacturerAndOnlyTheMatchingChannelLeaveResets() {
        var tracker = ShipChannelThemeTracker()
        let join = page([event(1, "shipChannelJoined", "RSI Aurora Mk I LN", aurora)])
        #expect(tracker.receive(join)?.theme == .manufacturer(.rsi))
        #expect(tracker.receive(join) == nil)
        #expect(tracker.receive(page([event(2, "shipChannelJoined", "Aegis Redeemer", redeemer)]))?.theme == .manufacturer(.aegis))
        #expect(tracker.receive(page([event(3, "shipChannelLeft", "RSI Aurora Mk I LN", aurora)])) == nil)
        #expect(tracker.receive(page([event(4, "shipChannelLeft", "Aegis Redeemer", redeemer)]))?.theme == .standard)
    }

    @Test func replayWaitsForLastPageAndDoesNotReapplyOnReconnect() {
        var tracker = ShipChannelThemeTracker()
        let first = page([event(1, "shipChannelJoined", "RSI Aurora Mk I LN", aurora)], latest: 2)
        let last = page([event(2, "shipChannelLeft", "RSI Aurora Mk I LN", aurora)])
        #expect(tracker.receive(first) == nil)
        #expect(tracker.receive(last)?.theme == .standard)
        #expect(tracker.receive(first) == nil)
        #expect(tracker.receive(last) == nil)
    }

    @Test func channelEventsDoNotMarkFinanceHistoryIncomplete() {
        let store = SessionActivityStore(fileURL: nil)
        store.receive(page([event(1, "shipChannelJoined", "RSI Aurora Mk I LN", aurora)]))
        #expect(store.channelThemeChange?.theme == .manufacturer(.rsi))
        #expect(!store.sessions[0].incomplete)
    }

    @Test func unknownChannelsAndInvalidIdentitiesCannotSelectATheme() {
        var tracker = ShipChannelThemeTracker()
        #expect(tracker.receive(page([event(1, "shipChannelJoined", "General", aurora)])) == nil)
        #expect(tracker.receive(page([event(2, "shipChannelJoined", "Drakeville Social", redeemer)])) == nil)
        #expect(!event(3, "shipChannelJoined", "Drake Cutter", "bad").isValid)
    }

    @Test func oldSavedChannelEventsWithoutIdentityRemainReadableButCannotSwitchThemes() {
        var tracker = ShipChannelThemeTracker()
        var legacy = event(1, "shipChannelJoined", "Drake Cutter", aurora)
        legacy.channelId = nil
        #expect(legacy.isValid)
        #expect(tracker.receive(page([legacy])) == nil)
    }

    @Test func channelIdentitySurvivesDecodingAndHistoryEncoding() throws {
        let original = event(1, "shipChannelJoined", "Drake Cutter", aurora)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SessionActivityEvent.self, from: encoded)
        #expect(decoded.channelId == aurora)
        #expect(decoded == original)
    }

    @Test func aReplayGapPreventsALeaveFromUsingAnOutdatedAssociation() {
        var tracker = ShipChannelThemeTracker()
        _ = tracker.receive(page([event(1, "shipChannelJoined", "RSI Aurora Mk I LN", aurora)]))
        #expect(tracker.receive(page([event(45, "shipChannelLeft", "RSI Aurora Mk I LN", aurora)])) == nil)
        #expect(!tracker.hasEvidence)
    }
}
