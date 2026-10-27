import Foundation
import Testing
@testable import SCMFD

/// Protocol v2 wire format against the examples in section 41 of CSMFD-discussion.md.
struct ProtocolV2Tests {
    // MARK: - Fixtures from the spec

    static let sessionId = "7a42291e-21db-4ac5-a3e1-ea278bb54900"
    static let generation = "982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1"
    static let shipContext = #"{"revision":4,"status":"noShip","reason":"clearDriver","contextId":"e21848e3-803a-4257-8706-53df116bf9ce","manufacturerPrefix":"DRAK","observedAt":"2026-10-27T00:01:00.708Z"}"#

    static let fullState = #"""
    {"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":12,"partial":false,
    "game":{"running":true,"focused":true,"build":null},
    "log":{"status":"ready","generation":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","observedAt":"2026-10-27T00:00:00Z"},
    "ship":{"name":"Drake Cutter Rambler","model":"DRAK_Cutter_Rambler","entityId":"903627021939","manufacturerPrefix":"DRAK","confidence":"assumed","observedAt":"2026-10-27T00:00:00Z"},
    "shipContext":{"revision":3,"status":"assumed","reason":"channelJoined","contextId":"e21848e3-803a-4257-8706-53df116bf9ce","manufacturerPrefix":"DRAK","observedAt":"2026-10-27T00:00:00Z"},
    "qtTarget":{"mode":"unknown","internalName":null,"displayName":null,"confidence":"stale","observedAt":null},
    "hangarRequest":{"status":"idle","commandId":null,"contextId":null,"since":null,"updatedAt":null}}
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
        #expect(context.reason == .channelJoined)
    }

    @Test func clearDriverDeltaSeparatesNullFromAbsent() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":13,"partial":true,"ship":null,"shipContext":\#(Self.shipContext)}"#)
        #expect(state.ship == .value(nil))
        #expect(state.game == .absent)
        #expect(state.qtTarget == .absent)
    }

    @Test func deltaWithoutShipLeavesShipAbsent() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":14,"partial":true,"game":{"running":true,"focused":false,"build":"12913470"}}"#)
        #expect(state.ship == .absent)
        #expect(state.game == .value(GameStatus(running: true, focused: false, build: "12913470")))
    }

    @Test func datesKeepMilliseconds() throws {
        let state = try state(#"{"v":2,"type":"state","sessionId":"\#(Self.sessionId)","seq":15,"partial":true,"shipContext":\#(Self.shipContext)}"#)
        guard case .value(let context) = state.shipContext else {
            Issue.record("Expected a ship context")
            return
        }
        let seconds = try #require(context.observedAt?.timeIntervalSince1970)
        // Double cannot hold .708 exactly; a tolerance well below 1 ms still proves the fraction survived.
        #expect(abs(seconds - 1_793_059_260.708) < 0.000_5)
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

    @Test func ackMapsKnownReason() throws {
        let message = try decode(#"{"v":2,"type":"ack","id":"9b38e72e-4b86-455c-95c6-e3c2d782f172","status":"rejected","reason":"game_not_focused"}"#)
        guard case .ack(let ack) = message else {
            Issue.record("Expected an ack")
            return
        }
        #expect(ack.rejectReason == .gameNotFocused)
    }

    @Test func inputCancelledCarriesCommandId() throws {
        let message = try decode(#"{"v":2,"type":"error","code":"input_cancelled","commandId":"4d88b2ad-d306-443a-8524-155575227708","reason":"focus_lost","message":"Input cancelled"}"#)
        guard case .error(let error) = message else {
            Issue.record("Expected an error")
            return
        }
        #expect(error.code == "input_cancelled")
        #expect(error.commandId == UUID(uuidString: "4d88b2ad-d306-443a-8524-155575227708"))
        #expect(error.reason == "focus_lost")
    }

    @Test func handshakeMessagesDecode() throws {
        #expect(try decode(#"{"v":2,"type":"pairRequired"}"#) == .pairRequired)
        guard case .welcome(let welcome) = try decode(#"{"v":2,"type":"welcome","server":"CSMFD-Server","serverVersion":"0.1.0","serverId":"366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","connectionId":"a42a3cd9-a193-457b-b2dd-a973e3d9b35a","chatKey":"enter"}"#) else {
            Issue.record("Expected welcome")
            return
        }
        #expect(welcome.chatKey == "enter")
        guard case .paired(let paired) = try decode(#"{"v":2,"type":"paired","serverId":"366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1","token":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"}"#) else {
            Issue.record("Expected paired")
            return
        }
        #expect(paired.token.count == 43)
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
        // Unknown enum value in a strictly typed field.
        #"{"v":2,"type":"state","sessionId":"7a42291e-21db-4ac5-a3e1-ea278bb54900","seq":3,"partial":true,"log":{"status":"exploded","generation":"982ba1b6-1aa8-4e7e-a73b-9a9e51abb8d1","observedAt":null}}"#,
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
