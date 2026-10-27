import Foundation
import Testing
@testable import CSMFD

struct PairingPayloadTests {
    // nonisolated: @Test arguments are evaluated outside the main actor.
    nonisolated static let serverId = "366b189f-9bb1-4aeb-bf8b-235a5cdcf9e1"
    nonisolated static let fingerprint = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

    private func parse(_ link: String) throws(PairingPayload.ParseError) -> PairingPayload {
        guard let url = URL(string: link) else { throw .notPairingLink }
        return try PairingPayload(url: url)
    }

    private func link(_ query: String) -> String { "csmfd://pair?\(query)" }

    @Test func validLinkParses() throws {
        let payload = try parse(link("v=2&host=192.168.1.67&port=47823&id=\(Self.serverId)&fp=\(Self.fingerprint)"))
        #expect(payload.host == "192.168.1.67")
        #expect(payload.port == 47823)
        #expect(payload.serverId == UUID(uuidString: Self.serverId))
        #expect(payload.fingerprint.count == 32)
        #expect(payload.fingerprint.first == 0x01)
        #expect(payload.fingerprint.last == 0xef)
    }

    @Test func uppercaseFingerprintAndUnknownItemsAreAccepted() throws {
        let payload = try parse(link("v=2&host=10.0.0.5&port=47823&id=\(Self.serverId)&fp=\(Self.fingerprint.uppercased())&name=Gaming%20PC"))
        #expect(payload.fingerprint == PairingPayload.fingerprintBytes(fromHex: Self.fingerprint))
    }

    @Test func groupedFingerprintMatchesPCWindow() throws {
        let payload = try parse(link("v=2&host=172.16.0.1&port=47823&id=\(Self.serverId)&fp=\(Self.fingerprint)"))
        #expect(payload.groupedFingerprint.hasPrefix("0123 4567 89ab cdef"))
        #expect(payload.groupedFingerprint.split(separator: " ").count == 16)
    }

    @Test(arguments: [
        ("https://pair?v=2", PairingPayload.ParseError.notPairingLink),
        ("csmfd://connect?v=2", .notPairingLink),
        ("csmfd://pair/extra?v=2", .notPairingLink),
        ("csmfd://pair?v=1&host=192.168.1.67&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .unsupportedVersion("1")),
        ("csmfd://pair?v=2&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .missing("host")),
        // Two fingerprints: which one is pinned must not depend on parser order.
        ("csmfd://pair?v=2&host=192.168.1.67&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)&fp=\(PairingPayloadTests.fingerprint)", .duplicate("fp")),
        ("csmfd://pair?v=2&host=8.8.8.8&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .invalidHost),
        ("csmfd://pair?v=2&host=192.168.01.67&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .invalidHost),
        ("csmfd://pair?v=2&host=gaming-pc.local&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .invalidHost),
        ("csmfd://pair?v=2&host=192.168.1.67&port=70000&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .invalidPort),
        ("csmfd://pair?v=2&host=192.168.1.67&port=0&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint)", .invalidPort),
        ("csmfd://pair?v=2&host=192.168.1.67&port=47823&id=not-a-uuid&fp=\(PairingPayloadTests.fingerprint)", .invalidServerId),
        ("csmfd://pair?v=2&host=192.168.1.67&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint.dropLast())", .invalidFingerprint),
        ("csmfd://pair?v=2&host=192.168.1.67&port=47823&id=\(PairingPayloadTests.serverId)&fp=\(PairingPayloadTests.fingerprint.dropLast())g", .invalidFingerprint),
    ])
    func invalidLinkIsRejected(link: String, expected: PairingPayload.ParseError) {
        #expect(throws: expected) {
            try parse(link)
        }
    }

    @Test(arguments: ["10.0.0.1", "172.31.255.255", "192.168.0.1"])
    func privateAddressIsAccepted(address: String) {
        #expect(PrivateIPv4.isValid(address))
    }

    @Test(arguments: ["172.32.0.1", "192.169.0.1", "127.0.0.1", "10.0.0", "10.0.0.1.5", "10.0.0.256", " 10.0.0.1"])
    func otherAddressIsRejected(address: String) {
        #expect(!PrivateIPv4.isValid(address))
    }
}
