import Foundation
import Testing
@testable import SCMFD

struct WheelCommandTests {
    // Exact values from SCMFDBE tests/Csmfd.Tests/Fixtures/Protocol/client-wheel-*.json.
    nonisolated static let fixtures: [(WheelEvent.Action, WheelEvent.Step, String)] = [
        (.accelerationLimiter, .decrease,
         #"{"v":2,"type":"wheel","id":"71b5d971-9ef6-48af-b4ab-668a2b991104","action":"accelerationLimiter","step":-1}"#),
        (.accelerationLimiter, .increase,
         #"{"v":2,"type":"wheel","id":"71b5d971-9ef6-48af-b4ab-668a2b991103","action":"accelerationLimiter","step":1}"#),
        (.speedLimiter, .decrease,
         #"{"v":2,"type":"wheel","id":"71b5d971-9ef6-48af-b4ab-668a2b991102","action":"speedLimiter","step":-1}"#),
        (.speedLimiter, .increase,
         #"{"v":2,"type":"wheel","id":"71b5d971-9ef6-48af-b4ab-668a2b991101","action":"speedLimiter","step":1}"#)
    ]

    @Test(arguments: fixtures)
    func wireMatchesFixture(action: WheelEvent.Action, step: WheelEvent.Step, fixture: String) throws {
        let expected = try #require(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        let idString = try #require(expected["id"] as? String)
        let id = try #require(UUID(uuidString: idString))
        let data = try ProtocolV2.encode(.wheel(id: id, WheelEvent(action: action, step: step)))
        let encoded = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        #expect(encoded == expected as NSDictionary)
        // JSON must contain an integer token, not 1.0, an exponent, or a quoted number.
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.range(of: #""step":-?1[,}]"#, options: .regularExpression) != nil)
    }

    nonisolated static let outcomes: [CommandOutcome] = [
        .sent, .ignored, .rejected("busy"), .rejected("rate_limited"),
        .rejected("input_failed"), .unknown, .notSent(.notConnected), .notSent(.tooManyPending)
    ]

    @Test(arguments: outcomes)
    func sharedLimitDropsWithoutQueueingAndRecovers(outcome: CommandOutcome) async throws {
        let link = ControlledWheelLink()
        let deck = DeckState()
        let controller = deck.wheelCommands
        let first = try #require(controller.submit(.increase, for: .speedLimiter, link: link))
        #expect(controller.isPending)
        for _ in 0..<20 {
            #expect(controller.submit(.decrease, for: .accelerationLimiter, link: link) == nil)
            #expect(controller.submit(.increase, for: .speedLimiter, link: link) == nil)
        }
        deck.resetDeck()
        #expect(controller.submit(.decrease, for: .accelerationLimiter, link: link) == nil)
        #expect(link.events == [WheelEvent(action: .speedLimiter, step: .increase)])
        link.finish(outcome)
        await first.value
        #expect(!controller.isPending)
        #expect(link.events.count == 1)
        #expect(controller.failures[.speedLimiter] == (outcome.failureLabel == nil ? nil : outcome))
        #expect(controller.failure(for: .accelerationLimiter) == nil)

        let next = try #require(controller.submit(.decrease, for: .accelerationLimiter, link: link))
        #expect(link.events.last == WheelEvent(action: .accelerationLimiter, step: .decrease))
        #expect(Set(link.ids).count == 2)
        link.finish(.sent)
        await next.value
        let retryByUser = try #require(controller.submit(.decrease, for: .speedLimiter, link: link))
        #expect(controller.failure(for: .speedLimiter) == nil)
        link.finish(.sent)
        await retryByUser.value
        #expect(link.events.count == 3)
    }

    @Test(arguments: ["sent", "rejected", "unknownAck", "timeout", "disconnect", "unknownType"])
    func sessionSettlementReleasesBothDrumsWithoutReplay(ending: String) async throws {
        let now = ContinuousClock.now
        var session = try readySession(at: now)
        let controller = WheelCommandController()
        let link = ControlledWheelLink()
        let task = try #require(controller.submit(.increase, for: .speedLimiter, link: link))
        let id = try #require(link.ids.first)
        let event = try #require(link.events.first)
        #expect(session.send(.wheel(event), id: id, at: now) == [.send(.wheel(id: id, event))])
        #expect(controller.submit(.decrease, for: .accelerationLimiter, link: link) == nil)
        // An unrelated ack must not release the pending wheel.
        #expect(session.receive(.ack(ServerAck(id: UUID(), status: .sent, reason: nil)), at: now).isEmpty)
        #expect(controller.isPending)

        let effects: [SessionEffect]
        let expected: CommandOutcome
        switch ending {
        case "sent":
            effects = session.receive(.ack(ServerAck(id: id, status: .sent, reason: nil)), at: now)
            expected = .sent
        case "rejected":
            effects = session.receive(.ack(ServerAck(id: id, status: .rejected, reason: "busy")), at: now)
            expected = .rejected("busy")
        case "unknownAck":
            effects = session.receive(.ack(ServerAck(id: id, status: .unrecognized("future"), reason: nil)), at: now)
            expected = .unknown
        case "timeout":
            _ = session.receive(.unknown(type: "future"), at: now + .seconds(14))
            effects = session.tick(at: now + .seconds(15), wallClock: .now)
            #expect(effects.contains(.close(.acknowledgementTimeout)))
            expected = .unknown
        case "unknownType":
            let errorEffects = session.receive(.error(ServerError(code: "unknown_type", message: nil,
                                                                   commandId: nil, reason: nil)), at: now)
            #expect(errorEffects == [.serverError(code: "unknown_type", message: nil)])
            #expect(controller.isPending)
            // An older server's uncorrelated error leaves the ticket pending until the normal deadline.
            _ = session.receive(.unknown(type: "future"), at: now + .seconds(14))
            effects = session.tick(at: now + .seconds(15), wallClock: .now)
            expected = .unknown
        default:
            effects = session.transportClosed(code: nil)
            expected = .unknown
        }
        try #require(effects.contains(.commandFinished(id, expected)))
        #expect(!effects.contains { if case .send = $0 { true } else { false } })
        for effect in effects {
            if case .commandFinished(let finishedID, let outcome) = effect, finishedID == id {
                link.finish(outcome)
            }
        }
        await task.value
        #expect(!controller.isPending)
        #expect(link.events.count == 1)
        #expect(session.receive(.ack(ServerAck(id: id, status: .sent, reason: nil)), at: now).isEmpty)

        // A new connection starts with no retained wheel work. Only a fresh user intention sends.
        session = try readySession(at: now)
        #expect(session.tick(at: now, wallClock: .now).isEmpty)
        let next = try #require(controller.submit(.decrease, for: .accelerationLimiter, link: link))
        let nextID = try #require(link.ids.last)
        let nextEvent = try #require(link.events.last)
        #expect(nextID != id)
        #expect(session.send(.wheel(nextEvent), id: nextID, at: now) == [.send(.wheel(id: nextID, nextEvent))])
        link.finish(.sent)
        await next.value
    }

    @Test func wheelBeforeWelcomeIsNotQueued() throws {
        let now = ContinuousClock.now
        var session = ServerSession(configuration: SessionConfiguration(appVersion: "test", deviceName: "test"),
                                    serverId: nil, token: nil)
        let id = UUID()
        #expect(session.send(.wheel(WheelEvent(action: .speedLimiter, step: .increase)), id: id, at: now)
                == [.commandFinished(id, .notSent(.notConnected))])
        _ = session.transportOpened(at: now)
        let welcome = try ProtocolV2.decode(Data(ProtocolV2Tests.welcomeFixture.utf8))
        #expect(session.receive(welcome, at: now).isEmpty)
        #expect(session.tick(at: now, wallClock: .now).isEmpty)
    }

    private func readySession(at now: ContinuousClock.Instant) throws -> ServerSession {
        var session = ServerSession(configuration: SessionConfiguration(appVersion: "test", deviceName: "test"),
                                    serverId: nil, token: nil)
        _ = session.transportOpened(at: now)
        _ = session.receive(try ProtocolV2.decode(Data(ProtocolV2Tests.welcomeFixture.utf8)), at: now)
        return session
    }

    @Test func consoleAndDisconnectedNetworkReturnFreshSettledTickets() async {
        let event = WheelEvent(action: .speedLimiter, step: .increase)
        let console = ConsoleCommandLink()
        let first = console.send(wheel: event)
        let second = console.send(wheel: event)
        #expect(first.id != second.id)
        #expect(await first.outcome.value == .sent)
        #expect(await second.outcome.value == .sent)

        let connection = ServerConnection()
        let network = NetworkCommandLink(connection: connection)
        let a = network.send(wheel: event)
        let b = network.send(wheel: event)
        #expect(a.id != b.id)
        #expect(await a.outcome.value == .notSent(.notConnected))
        #expect(await b.outcome.value == .notSent(.notConnected))
    }
}

/// Manually settled tickets exercise admission before any asynchronous work can start.
@MainActor
private final class ControlledWheelLink: CommandLink {
    var events: [WheelEvent] = []
    var ids: [UUID] = []
    private var continuation: AsyncStream<CommandOutcome>.Continuation?

    func send(wheel event: WheelEvent) -> CommandTicket {
        events.append(event)
        let id = UUID()
        ids.append(id)
        let (stream, continuation) = AsyncStream<CommandOutcome>.makeStream()
        self.continuation = continuation
        return CommandTicket(id: id, outcome: Task {
            for await outcome in stream { return outcome }
            return .unknown
        })
    }

    func finish(_ outcome: CommandOutcome) {
        continuation?.yield(outcome)
        continuation?.finish()
        continuation = nil
    }

    func send(_ event: KeyEvent) -> CommandTicket {
        Issue.record("Wheel sent a key event")
        return .immediate(.unknown)
    }

    func send(chat event: ChatEvent) -> CommandTicket {
        Issue.record("Wheel sent a chat event")
        return .immediate(.unknown)
    }
}
