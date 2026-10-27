import Foundation
import Testing
@testable import SCMFD

struct ServerSessionTests {
    static let serverId = UUID(uuidString: "366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1")!
    static let sessionId = UUID(uuidString: "7a42291e-21db-4ac5-a3e1-ea278bb54900")!
    static let connectionId = UUID(uuidString: "a42a3cd9-a193-457b-b2dd-a973e3d9b35a")!
    static let configuration = SessionConfiguration(appVersion: "0.1.0", deviceName: "Palantír")

    let t0 = ContinuousClock.now
    let wallClock = Date(timeIntervalSince1970: 1_800_000_000)

    private func at(_ seconds: Double) -> ContinuousClock.Instant {
        t0 + .milliseconds(Int(seconds * 1000))
    }

    private func welcome(serverId: UUID = serverId) -> ServerWelcome {
        ServerWelcome(server: "CSMFD-Server", serverVersion: "0.1.0", serverId: serverId,
                      sessionId: Self.sessionId, connectionId: Self.connectionId, chatKey: "enter")
    }

    private func state(seq: Int, partial: Bool, sessionId: UUID = sessionId) -> ServerState {
        let game = StateField.value(GameStatus(running: true, focused: true, build: nil))
        return ServerState(
            sessionId: sessionId, seq: seq, partial: partial,
            game: game,
            log: partial ? .absent : .value(LogStatus(status: .ready, generation: UUID(), observedAt: nil)),
            ship: partial ? .absent : .value(nil),
            shipContext: partial ? .absent : .value(ShipContextStatus(
                revision: 0, status: .unknown, reason: .startup, contextId: nil, manufacturerPrefix: nil, observedAt: nil)),
            qtTarget: partial ? .absent : .value(QuantumTargetStatus(
                mode: .unknown, internalName: nil, displayName: nil, confidence: .stale, observedAt: nil)),
            hangarRequest: partial ? .absent : .value(HangarRequestState(
                status: .idle, commandId: nil, contextId: nil, since: nil, updatedAt: nil))
        )
    }

    /// A paired session that went through hello → welcome at t0.
    private func readySession() -> ServerSession {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: "token")
        _ = session.transportOpened(at: t0)
        _ = session.receive(.welcome(welcome()), at: t0)
        return session
    }

    // MARK: - Handshake

    @Test func openSendsHelloWithStoredToken() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: "token")
        let effects = session.transportOpened(at: t0)
        #expect(effects == [.send(.hello(ClientHello(appVersion: "0.1.0", deviceName: "Palantír", token: "token")))])
        #expect(session.phase == .awaitingWelcome)
    }

    @Test func pairingFlowSavesTokenThenBecomesReady() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: nil)
        _ = session.transportOpened(at: t0)
        #expect(session.receive(.pairRequired, at: at(0.1)).isEmpty)
        #expect(session.phase == .pairingRequired)
        #expect(session.submitPairingCode("48291", at: at(1)).isEmpty) // 5 digits: ignored
        #expect(session.submitPairingCode("482913", at: at(1)) == [.send(.pair(code: "482913"))])
        let paired = ServerPaired(serverId: Self.serverId, token: "new-token")
        #expect(session.receive(.paired(paired), at: at(1.2)) == [.savePairing(serverId: Self.serverId, token: "new-token")])
        #expect(session.receive(.welcome(welcome()), at: at(1.3)).isEmpty)
        #expect(session.phase == .ready(welcome()))
    }

    @Test func manualPairingLearnsServerIdFromPaired() {
        var session = ServerSession(configuration: Self.configuration, serverId: nil, token: nil)
        _ = session.transportOpened(at: t0)
        _ = session.receive(.pairRequired, at: t0)
        _ = session.submitPairingCode("482913", at: t0)
        _ = session.receive(.paired(ServerPaired(serverId: Self.serverId, token: "t")), at: t0)
        // A welcome from any other server must now be refused.
        let other = welcome(serverId: UUID())
        #expect(session.receive(.welcome(other), at: t0) == [.close(.serverIdentityMismatch)])
    }

    @Test func welcomeFromAnotherServerIsRefused() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: "token")
        _ = session.transportOpened(at: t0)
        #expect(session.receive(.welcome(welcome(serverId: UUID())), at: t0) == [.close(.serverIdentityMismatch)])
    }

    @Test func wrongCodeAllowsAnotherAttempt() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: nil)
        _ = session.transportOpened(at: t0)
        _ = session.receive(.pairRequired, at: t0)
        _ = session.submitPairingCode("111111", at: t0)
        let error = ServerError(code: "pair_invalid", message: "Wrong code", commandId: nil, reason: nil)
        #expect(session.receive(.error(error), at: t0) == [.pairingCodeRejected(code: "pair_invalid")])
        #expect(session.phase == .pairingRequired)
    }

    @Test func closedPairingWindowEndsSession() {
        var session = ServerSession(configuration: Self.configuration, serverId: nil, token: nil)
        _ = session.transportOpened(at: t0)
        let error = ServerError(code: "pair_unavailable", message: nil, commandId: nil, reason: nil)
        #expect(session.receive(.error(error), at: t0) == [.close(.pairingUnavailable)])
        #expect(!SessionCloseReason.pairingUnavailable.allowsReconnect)
    }

    // MARK: - Timers

    @Test func noPingBeforeWelcomeAndHandshakeTimesOut() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: "token")
        _ = session.transportOpened(at: t0)
        #expect(session.tick(at: at(9.9), wallClock: wallClock).isEmpty)
        #expect(session.tick(at: at(10), wallClock: wallClock) == [.close(.handshakeTimeout)])
    }

    @Test func waitingForTheCodeUsesThePairingWindowNotLiveness() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: nil)
        _ = session.transportOpened(at: t0)
        _ = session.receive(.pairRequired, at: t0)
        // The server is silent while the user reads the code; 60 s must not close the session.
        #expect(session.tick(at: at(60), wallClock: wallClock).isEmpty)
        #expect(session.tick(at: at(120), wallClock: wallClock) == [.close(.pairingTimeout)])
    }

    @Test func readySessionPingsEveryFiveSecondsAndMeasuresRoundTrip() {
        var session = readySession()
        #expect(session.tick(at: at(4.9), wallClock: wallClock).isEmpty)
        #expect(session.tick(at: at(5), wallClock: wallClock) == [.send(.ping(id: "p-1", unixMilliseconds: 1_800_000_000_000))])
        #expect(session.receive(.pong(ServerPong(id: "p-1", t: 1_800_000_000_000)), at: at(5.003)) == [.roundTrip(.milliseconds(3))])
        #expect(session.tick(at: at(9.9), wallClock: wallClock).isEmpty)
        #expect(session.tick(at: at(10), wallClock: wallClock).first == .send(.ping(id: "p-2", unixMilliseconds: 1_800_000_000_000)))
    }

    @Test func tenSecondsOfSilenceClosesAndSettlesPendingAsUnknown() {
        var session = readySession()
        let id = UUID()
        _ = session.send(.key(KeyEvent(action: .lights, phase: .down, timestamp: wallClock)), id: id)
        // Every message from the server resets liveness.
        _ = session.receive(.unknown(type: "future"), at: at(4))
        #expect(!session.tick(at: at(13.9), wallClock: wallClock).contains(.close(.livenessTimeout)))
        #expect(session.tick(at: at(14), wallClock: wallClock) == [.commandFinished(id, .unknown), .close(.livenessTimeout)])
        #expect(SessionCloseReason.livenessTimeout.allowsReconnect)
    }

    // MARK: - State ordering

    @Test func stateBeforeWelcomeIsAViolation() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: "token")
        _ = session.transportOpened(at: t0)
        #expect(session.receive(.state(state(seq: 1, partial: false)), at: t0) == [.close(.protocolViolation("state before welcome"))])
    }

    @Test func firstStateMustBeFull() {
        var session = readySession()
        #expect(session.receive(.state(state(seq: 1, partial: true)), at: t0) == [.close(.protocolViolation("first state is a delta"))])
    }

    @Test func olderOrRepeatedSeqIsDropped() {
        var session = readySession()
        let full = state(seq: 12, partial: false)
        #expect(session.receive(.state(full), at: t0) == [.state(full)])
        #expect(session.receive(.state(state(seq: 12, partial: true)), at: t0).isEmpty)
        #expect(session.receive(.state(state(seq: 11, partial: true)), at: t0).isEmpty)
        let next = state(seq: 15, partial: true) // gaps are allowed
        #expect(session.receive(.state(next), at: t0) == [.state(next)])
    }

    @Test func stateFromAnotherSessionIsAViolation() {
        var session = readySession()
        let foreign = state(seq: 1, partial: false, sessionId: UUID())
        #expect(session.receive(.state(foreign), at: t0) == [.close(.protocolViolation("state from another session"))])
    }

    // MARK: - Commands

    @Test func commandBeforeReadyIsNotSentOrQueued() {
        var session = ServerSession(configuration: Self.configuration, serverId: Self.serverId, token: "token")
        let id = UUID()
        #expect(session.send(.releaseAll, id: id) == [.commandFinished(id, .notSent(.notConnected))])
    }

    @Test func ackFinishesTheMatchingCommandOnce() {
        var session = readySession()
        let id = UUID()
        #expect(session.send(.chat("/wave"), id: id) == [.send(.chat(id: id, text: "/wave"))])
        let ack = ServerAck(id: id, status: .rejected, reason: "busy")
        #expect(session.receive(.ack(ack), at: t0) == [.commandFinished(id, .rejected("busy"))])
        // A duplicate ack does not finish it twice.
        #expect(session.receive(.ack(ack), at: t0).isEmpty)
    }

    @Test func pendingCommandsAreBounded() {
        var session = readySession()
        for _ in 0..<32 { _ = session.send(.releaseAll, id: UUID()) }
        let id = UUID()
        #expect(session.send(.releaseAll, id: id) == [.commandFinished(id, .notSent(.tooManyPending))])
    }

    @Test func cancelledHoldIsReportedWithItsCommandId() {
        var session = readySession()
        let id = UUID()
        let error = ServerError(code: "input_cancelled", message: "Input cancelled", commandId: id, reason: "focus_lost")
        #expect(session.receive(.error(error), at: t0) == [.inputEnded(commandId: id, code: "input_cancelled", reason: "focus_lost")])
    }

    // MARK: - Close codes

    @Test func revokedDeviceForgetsPairingAndDoesNotReconnect() {
        var session = readySession()
        let id = UUID()
        _ = session.send(.releaseAll, id: id)
        #expect(session.transportClosed(code: 4006) == [.commandFinished(id, .unknown), .forgetPairing])
        #expect(!SessionCloseReason.closedByServer(code: 4006).allowsReconnect)
        // Nothing is sent on a closed session.
        let late = UUID()
        #expect(session.send(.releaseAll, id: late) == [.commandFinished(late, .notSent(.notConnected))])
    }

    @Test(arguments: [(4001, false), (4002, false), (4003, false), (4004, true), (4005, true), (1000, true)])
    func reconnectPolicyFollowsCloseCode(code: Int, allowsReconnect: Bool) {
        #expect(SessionCloseReason.closedByServer(code: code).allowsReconnect == allowsReconnect)
    }

    @Test func droppedConnectionWithoutCodeAllowsReconnect() {
        #expect(SessionCloseReason.closedByServer(code: nil).allowsReconnect)
    }
}

struct ReconnectBackoffTests {
    @Test func delayDoublesThenCapsAtThirtySeconds() {
        let delays = (0..<8).map(ServerConnection.reconnectDelay(afterFailures:))
        #expect(delays == [1, 2, 4, 8, 16, 30, 30, 30])
    }
}
