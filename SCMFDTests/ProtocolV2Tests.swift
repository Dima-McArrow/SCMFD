import Foundation
import Testing
@testable import SCMFD

/// Protocol v2 wire format against the examples in section 41 of CSMFD-discussion.md.
struct ProtocolV2Tests {
    // MARK: - Fixtures from the spec

    static let sessionId = "7a42291e-21db-4ac5-a3e1-ea278bb54900"
    static let generation = "982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1"
    /// The 41 spec example; its `.708` fraction proves milliseconds survive. Not a server fixture.
    static let millisecondShipContext = #"{"revision":4,"status":"noShip","reason":"clearDriver","contextId":"e21848e3-803a-4257-8706-53df116bf9ce","manufacturerPrefix":"DRAK","observedAt":"2026-10-27T00:01:00.708Z"}"#

    // SCMFDBE `tests/Csmfd.Tests/Fixtures/Protocol`: the same JSON values, compacted.

    /// `server-state-full.json`.
    static let fullState = #"""
    {"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":12,"partial":false,
    "game":{"running":true,"focused":true,"build":null},
    "log":{"status":"ready","generation":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","observedAt":"2026-10-27T00:00:00.000Z"},
    "ship":{"name":"Drake Cutter Rambler","model":"DRAK_Cutter_Rambler","entityId":"903627021939","manufacturerPrefix":"DRAK","confidence":"assumed","observedAt":"2026-10-27T00:00:00.000Z"},
    "shipContext":{"revision":3,"status":"assumed","reason":"channelJoined","contextId":"e21848e3-803a-4257-8706-53df116bf9ce","manufacturerPrefix":"DRAK","observedAt":"2026-10-27T00:00:00.000Z"},
    "qtTarget":{"mode":"unknown","internalName":null,"displayName":null,"confidence":"stale","observedAt":null},
    "hangarRequest":{"status":"idle","commandId":null,"contextId":null,"since":null,"updatedAt":null}}
    """#

    /// Inline "older server" sample: a ClearDriver delta as servers before 41.23 sent it. The SCMFDBE fixture
    /// `server-state-delta-clear-driver.json` it was copied from no longer exists (removed server side).
    static let clearDriverDelta = #"""
    {"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":13,"partial":true,"ship":null,
    "shipContext":{"revision":4,"status":"noShip","reason":"clearDriver","contextId":"e21848e3-803a-4257-8706-53df116bf9ce","manufacturerPrefix":"DRAK","observedAt":"2026-10-27T00:01:00.000Z"},
    "qtTarget":{"mode":"unknown","internalName":null,"displayName":null,"confidence":"stale","observedAt":null},
    "hangarRequest":{"status":"idle","commandId":null,"contextId":null,"since":null,"updatedAt":null}}
    """#

    /// `server-state-delta-vehicle-destroyed.json` (41.23).
    static let vehicleDestroyedDelta = #"""
    {"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":14,"partial":true,"ship":null,
    "shipContext":{"revision":5,"status":"noShip","reason":"vehicleDestroyed","contextId":"e21848e3-803a-4257-8706-53df116bf9ce","manufacturerPrefix":"DRAK","observedAt":"2026-10-27T00:02:00.000Z"},
    "qtTarget":{"mode":"unknown","internalName":null,"displayName":null,"confidence":"stale","observedAt":null},
    "hangarRequest":{"status":"idle","commandId":null,"contextId":null,"since":null,"updatedAt":null}}
    """#

    /// `server-welcome.json`.
    static let welcomeFixture = #"{"v":2,"type":"welcome","server":"CSMFD-Server","serverVersion":"0.1.0","serverId":"366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","connectionId":"a42a3cd9-a193-457b-b2dd-a973e3d9b35a","chatKey":"enter"}"#
    /// `server-paired.json`.
    static let pairedFixture = #"{"v":2,"type":"paired","serverId":"366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1","token":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"#
    /// `server-pair-required.json`.
    static let pairRequiredFixture = #"{"v":2,"type":"pairRequired"}"#
    /// `server-error-input-cancelled.json`.
    static let inputCancelledFixture = #"{"v":2,"type":"error","code":"input_cancelled","commandId":"4d88b2ad-d306-443a-8524-155575227708","reason":"focus_lost","message":"Input cancelled"}"#
    /// `server-ack-rejected-game-not-focused.json`.
    static let ackRejectedFixture = #"{"v":2,"type":"ack","id":"9b38e72e-4b86-455c-95c6-e3c2d782f172","status":"rejected","reason":"game_not_focused"}"#
    /// `server-activity-rewards.json`.
    static let activityRewardsFixture = #"""
    {"v":2,"type":"activity","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","streamId":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1",
    "startedAt":"2026-10-27T12:00:00.000Z","firstSeq":1,"latestSeq":1,"ended":false,
    "events":[{"seq":1,"kind":"reward","at":"2026-10-27T12:00:01.000Z","text":"Awarded 500 aUEC:","amount":500,"currency":"aUEC"}]}
    """#

    private func decode(_ json: String) throws -> ServerMessage {
        try ProtocolV2.decode(Data(json.utf8))
    }

    private func state(_ json: String) throws -> ServerState {
        guard case .state(let state) = try decode(json) else {
            Issue.record("Expected a state message")
            throw CancellationError()
        }
        return state
    }

    private func object(_ message: ClientMessage) throws -> [String: Any] {
        let data = try ProtocolV2.encode(message)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - iPad → server

    @Test func helloSendsExplicitNullToken() throws {
        let data = try ProtocolV2.encode(.hello(ClientHello(appVersion: "0.1.0", deviceName: "Dima iPad", token: nil)))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // The key must exist and hold NSNull: a missing field is malformed for the server.
        #expect(json["token"] is NSNull)
        #expect(json["v"] as? Int == 2)
        #expect(json["type"] as? String == "hello")
        #expect(json["client"] as? String == "CSMFD-iPad")
    }

    @Test func tapKeyMatchesSpecExample() throws {
        let id = try #require(UUID(uuidString: "4d88b2ad-d306-443a-8524-155575227708"))
        let json = try object(.key(id: id, KeyEvent(action: .requestLanding, phase: .down)))
        #expect(json["id"] as? String == "4d88b2ad-d306-443a-8524-155575227708")
        #expect(json["action"] as? String == "requestLanding")
        #expect(json["phase"] as? String == "down")
        #expect(json["key"] as? String == "n")
        #expect(json["mods"] as? [String] == ["alt"])
        #expect(json["ms"] == nil)
    }

    @Test func holdKeyCarriesMilliseconds() throws {
        let json = try object(.key(id: UUID(), KeyEvent(action: .quantumEngage, phase: .hold(milliseconds: 1500))))
        #expect(json["phase"] as? String == "hold")
        #expect(json["key"] as? String == "mouse1")
        #expect(json["mods"] as? [String] == [])
        #expect(json["ms"] as? Int == 1500)
    }

    @Test func chatTextKeepsSlashUnescaped() throws {
        let data = try ProtocolV2.encode(.chat(id: UUID(), text: "/asl_thanks2"))
        #expect(String(decoding: data, as: UTF8.self).contains(#""text":"/asl_thanks2""#))
    }

    // MARK: - SCMFDBE client fixtures

    /// Each client message next to its SCMFDBE fixture (same JSON values, compacted).
    nonisolated static let clientFixtures: [(ClientMessage, String)] = [
        (.hello(ClientHello(appVersion: "0.1.0", deviceName: "Dima iPad", token: nil)),
         #"{"v":2,"type":"hello","client":"CSMFD-iPad","appVersion":"0.1.0","deviceName":"Dima iPad","token":null}"#),
        (.pair(code: "482913"),
         #"{"v":2,"type":"pair","code":"482913"}"#),
        (.ping(id: "p-123", unixMilliseconds: 1_793_040_000_000),
         #"{"v":2,"type":"ping","id":"p-123","t":1793040000000}"#),
        (.key(id: UUID(uuidString: "4d88b2ad-d306-443a-8524-155575227708")!,
              KeyEvent(action: .requestLanding, phase: .down)),
         #"{"v":2,"type":"key","id":"4d88b2ad-d306-443a-8524-155575227708","action":"requestLanding","phase":"down","key":"n","mods":["alt"]}"#),
        (.key(id: UUID(uuidString: "9b33e72e-4b86-455c-95c6-e3c2d782f172")!,
              KeyEvent(action: .quantumEngage, phase: .hold(milliseconds: 1500))),
         #"{"v":2,"type":"key","id":"9b33e72e-4b86-455c-95c6-e3c2d782f172","action":"quantumEngage","phase":"hold","key":"mouse1","ms":1500}"#),
        (.chat(id: UUID(uuidString: "c41d0b6e-2f7a-4c55-9a43-8f0e7e1b2a10")!, text: "/dance3"),
         #"{"v":2,"type":"chat","id":"c41d0b6e-2f7a-4c55-9a43-8f0e7e1b2a10","text":"/dance3"}"#),
        (.releaseAll(id: UUID(uuidString: "e0f1a2b3-c4d5-4e6f-8a9b-0c1d2e3f4a5b")!),
         #"{"v":2,"type":"releaseAll","id":"e0f1a2b3-c4d5-4e6f-8a9b-0c1d2e3f4a5b"}"#),
    ]

    /// Compared as JSON objects: key order and whitespace do not matter, an extra or missing key does.
    @Test(arguments: clientFixtures)
    func clientMessageMatchesServerFixture(message: ClientMessage, fixture: String) throws {
        let encoded = try #require(JSONSerialization.jsonObject(with: ProtocolV2.encode(message)) as? NSDictionary)
        let expected = try #require(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        var normalized = expected
        // `mods` is optional with a default of `[]` (40, key fields). The iPad always sends it; the server's hold
        // fixture omits it. Both mean the same, so a missing `mods` counts as `[]`.
        if normalized["type"] as? String == "key", normalized["mods"] == nil {
            normalized["mods"] = [String]()
        }
        #expect(encoded == normalized as NSDictionary)
    }

    /// `server-ack-sent.json`.
    @Test func ackSentFixtureDecodes() throws {
        let message = try decode(#"{"v":2,"type":"ack","id":"4d88b2ad-d306-443a-8524-155575227708","status":"sent"}"#)
        let id = try #require(UUID(uuidString: "4d88b2ad-d306-443a-8524-155575227708"))
        #expect(message == .ack(ServerAck(id: id, status: .sent, reason: nil)))
    }

    /// `server-pong.json`: echoes the ping fixture's id and time.
    @Test func pongFixtureDecodes() throws {
        let message = try decode(#"{"v":2,"type":"pong","id":"p-123","t":1793040000000}"#)
        #expect(message == .pong(ServerPong(id: "p-123", t: 1_793_040_000_000)))
    }

    // MARK: - Server → iPad

    @Test func fullSnapshotDecodes() throws {
        let state = try state(Self.fullState)
        #expect(state.sessionId == UUID(uuidString: Self.sessionId))
        #expect(state.seq == 12)
        #expect(state.partial == false)
        guard case .value(let ship?) = state.ship else {
            Issue.record("Expected a ship")
            return
        }
        #expect(ship.manufacturerPrefix == "DRAK")
        #expect(ship.confidence == .assumed)
        guard case .value(let context) = state.shipContext else {
            Issue.record("Expected a ship context")
            return
        }
        #expect(context.revision == 3)
        #expect(context.knownReason == .channelJoined)
    }

    @Test func clearDriverDeltaSeparatesNullFromAbsent() throws {
        let state = try state(Self.clearDriverDelta)
        #expect(state.ship == .value(nil))
        #expect(state.game == .absent)
        #expect(state.log == .absent)
    }

    @Test func deltaWithoutShipLeavesShipAbsent() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":14,"partial":true,"game":{"running":true,"focused":false,"build":"12913470"}}"#)
        #expect(state.ship == .absent)
        #expect(state.game == .value(GameStatus(running: true, focused: false, build: "12913470")))
    }

    @Test func datesKeepMilliseconds() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":15,"partial":true,"shipContext":\#(Self.millisecondShipContext)}"#)
        guard case .value(let context) = state.shipContext else {
            Issue.record("Expected a ship context")
            return
        }
        let seconds = try #require(context.observedAt?.timeIntervalSince1970)
        // Double cannot hold .708 exactly; a tolerance well below 1 ms still proves the fraction survived.
        #expect(abs(seconds - 1_793_059_260.708) < 0.000_5)
    }

    @Test func vehicleDestroyedDeltaDecodes() throws {
        let state = try state(Self.vehicleDestroyedDelta)
        #expect(state.ship == .value(nil))
        guard case .value(let context) = state.shipContext else {
            Issue.record("Expected a ship context")
            return
        }
        #expect(context.revision == 5)
        #expect(context.status == .noShip)
        #expect(context.knownReason == .vehicleDestroyed)
    }

    @Test func unknownShipContextReasonKeepsItsRawString() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":16,"partial":true,"shipContext":{"revision":6,"status":"assumed","reason":"somethingNew","contextId":null,"manufacturerPrefix":null,"observedAt":null}}"#)
        guard case .value(let context) = state.shipContext else {
            Issue.record("Expected a ship context")
            return
        }
        #expect(context.knownReason == .unknown)
        // Debug shows what the server actually sent.
        #expect(context.reason == "somethingNew")
        // The rest of the context still counts: the Deck follows `status`.
        #expect(context.status == .assumed)
        #expect(context.revision == 6)
    }

    // MARK: - Unknown values in server enums (LenientWireEnum): kept as `.unrecognized(word)`

    /// Was the "Unknown enum value in a strictly typed field" malformed case: a new value must not end the link.
    @Test func unknownLogStatusKeepsTheServerWord() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":3,"partial":true,"log":{"status":"exploded","generation":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","observedAt":null}}"#)
        guard case .value(let log) = state.log else {
            Issue.record("Expected a log status")
            return
        }
        #expect(log.status == .unrecognized("exploded"))
        // The Debug screen prints `wireValue`: the word the server sent.
        #expect(log.status.wireValue == "exploded")
    }

    @Test func unknownShipContextStatusKeepsTheServerWord() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":4,"partial":true,"shipContext":{"revision":7,"status":"parked","reason":"startup","contextId":null,"manufacturerPrefix":null,"observedAt":null}}"#)
        guard case .value(let context) = state.shipContext else {
            Issue.record("Expected a ship context")
            return
        }
        #expect(context.status == .unrecognized("parked"))
        #expect(context.status.wireValue == "parked")
        // The server's own "unknown" stays a separate, known case.
        #expect(try self.state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":8,"partial":true,"shipContext":{"revision":8,"status":"unknown","reason":"startup","contextId":null,"manufacturerPrefix":null,"observedAt":null}}"#).shipContext
                == .value(ShipContextStatus(revision: 8, status: .unknown, reason: "startup", contextId: nil,
                                            manufacturerPrefix: nil, observedAt: nil)))
    }

    @Test func unknownConfidenceKeepsTheServerWord() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":5,"partial":true,"ship":{"name":"Drake Cutter Rambler","model":null,"entityId":null,"manufacturerPrefix":"DRAK","confidence":"probable","observedAt":"2026-10-27T00:00:00.000Z"}}"#)
        guard case .value(let ship?) = state.ship else {
            Issue.record("Expected a ship")
            return
        }
        #expect(ship.confidence == .unrecognized("probable"))
        #expect(ship.confidence.wireValue == "probable")
    }

    @Test func unknownQuantumTargetModeKeepsTheServerWord() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":6,"partial":true,"qtTarget":{"mode":"jumping","internalName":"OOC_Stanton_1_Hurston","displayName":null,"confidence":"confirmed","observedAt":null}}"#)
        guard case .value(let target) = state.qtTarget else {
            Issue.record("Expected a QT target")
            return
        }
        #expect(target.mode == .unrecognized("jumping"))
        #expect(target.mode.wireValue == "jumping")
        // The readout does not invent a target from the name.
        #expect(QuantumTarget(target) == .unknown)
    }

    @Test func unknownHangarRequestStatusKeepsTheServerWord() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":7,"partial":true,"hangarRequest":{"status":"queued","commandId":null,"contextId":null,"since":null,"updatedAt":null}}"#)
        guard case .value(let request) = state.hangarRequest else {
            Issue.record("Expected a hangar request")
            return
        }
        #expect(request.status == .unrecognized("queued"))
        #expect(request.status.wireValue == "queued")
    }

    @Test func unknownAckStatusKeepsTheServerWord() throws {
        guard case .ack(let ack) = try decode(#"{"v":2,"type":"ack","id":"4d88b2ad-d306-443a-8524-155575227708","status":"deferred"}"#) else {
            Issue.record("Expected an ack")
            return
        }
        #expect(ack.status == .unrecognized("deferred"))
        #expect(ack.status.wireValue == "deferred")
    }

    @Test func ackKeepsUnknownReasonAsRawString() throws {
        let message = try decode(#"{"v":2,"type":"ack","id":"9b38e72e-4b86-455c-95c6-e3c2d782f172","status":"rejected","reason":"not_armed"}"#)
        guard case .ack(let ack) = message else {
            Issue.record("Expected an ack")
            return
        }
        #expect(ack.status == .rejected)
        #expect(ack.reason == "not_armed")
        #expect(ack.rejectReason == nil)
    }

    // MARK: - SCMFDBE server fixtures: every field (one `==` on the whole decoded message)

    @Test func ackRejectedFixtureDecodes() throws {
        let id = try #require(UUID(uuidString: "9b38e72e-4b86-455c-95c6-e3c2d782f172"))
        let message = try decode(Self.ackRejectedFixture)
        #expect(message == .ack(ServerAck(id: id, status: .rejected, reason: "game_not_focused")))
        guard case .ack(let ack) = message else { return }
        #expect(ack.rejectReason == .gameNotFocused)
    }

    @Test func inputCancelledFixtureDecodes() throws {
        let commandId = try #require(UUID(uuidString: "4d88b2ad-d306-443a-8524-155575227708"))
        #expect(try decode(Self.inputCancelledFixture) == .error(ServerError(
            code: "input_cancelled", message: "Input cancelled", commandId: commandId, reason: "focus_lost")))
    }

    @Test func pairRequiredFixtureDecodes() throws {
        #expect(try decode(Self.pairRequiredFixture) == .pairRequired)
    }

    @Test func welcomeFixtureDecodes() throws {
        let expected = ServerWelcome(
            server: "CSMFD-Server", serverVersion: "0.1.0",
            serverId: try #require(UUID(uuidString: "366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1")),
            sessionId: try #require(UUID(uuidString: Self.sessionId)),
            connectionId: try #require(UUID(uuidString: "a42a3cd9-a193-457b-b2dd-a973e3d9b35a")),
            chatKey: "enter")
        #expect(try decode(Self.welcomeFixture) == .welcome(expected))
    }

    @Test func pairedFixtureDecodes() throws {
        let serverId = try #require(UUID(uuidString: "366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1"))
        #expect(try decode(Self.pairedFixture) == .paired(ServerPaired(
            serverId: serverId, token: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")))
    }

    @Test func activityRewardsFixtureDecodesAndIsValid() throws {
        // 2026-10-27T12:00:00Z
        let startedAt = Date(timeIntervalSince1970: 1_793_102_400)
        let expected = ServerActivityPage(
            sessionId: try #require(UUID(uuidString: Self.sessionId)),
            streamId: try #require(UUID(uuidString: "982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1")),
            startedAt: startedAt, firstSeq: 1, latestSeq: 1, ended: false,
            events: [SessionActivityEvent(seq: 1, kind: "reward", at: startedAt.addingTimeInterval(1),
                                          text: "Awarded 500 aUEC:", missionId: nil, objectiveId: nil,
                                          amount: 500, currency: "aUEC")])
        let message = try decode(Self.activityRewardsFixture)
        #expect(message == .activity(expected))
        guard case .activity(let page) = message else { return }
        #expect(page.isValid)
    }

    @Test func unknownTypeIsIgnoredNotFatal() throws {
        #expect(try decode(#"{"v":2,"type":"mission"}"#) == .unknown(type: "mission"))
    }

    @Test func otherVersionIsRejected() {
        #expect(throws: ProtocolV2Error.unsupportedVersion(1)) {
            try decode(#"{"v":1,"type":"pairRequired"}"#)
        }
    }

    @Test(arguments: [
        // A full snapshot without qtTarget.
        #"{"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":1,"partial":false,"game":{"running":false,"focused":false,"build":null},"log":{"status":"ready","generation":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","observedAt":null},"ship":null,"shipContext":{"revision":0,"status":"unknown","reason":"startup","contextId":null,"manufacturerPrefix":null,"observedAt":null},"hangarRequest":{"status":"idle","commandId":null,"contextId":null,"since":null,"updatedAt":null}}"#,
        // null is only allowed for ship.
        #"{"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":2,"partial":true,"game":null}"#,
        // Wrong JSON type for an enum field: a new value is tolerated, a number is still malformed.
        #"{"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":3,"partial":true,"log":{"status":7,"generation":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","observedAt":null}}"#,
        // Date without a time zone.
        #"{"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":4,"partial":true,"shipContext":{"revision":1,"status":"noShip","reason":"clearDriver","contextId":null,"manufacturerPrefix":null,"observedAt":"2026-10-27 00:01"}}"#,
        // Missing required seq.
        #"{"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","partial":true}"#,
    ])
    func malformedStateIsRejected(json: String) {
        #expect(throws: (any Error).self) {
            try decode(json)
        }
    }
}
