import Foundation

/// Server identity from the pairing QR code shown on the PC:
/// `csmfd://pair?v=2&host=<ip>&port=47823&id=<serverId>&fp=<64 hex>`.
/// Holds no secret; it pins the certificate the iPad must see before it sends the code.
nonisolated struct PairingPayload: Sendable, Equatable {
    static let scheme = "csmfd"

    let host: String
    let port: UInt16
    let serverId: UUID
    /// SHA-256 of the server's DER certificate, 32 bytes.
    let fingerprint: Data

    nonisolated enum ParseError: Error, Equatable {
        case notPairingLink
        case unsupportedVersion(String)
        case missing(String)
        case duplicate(String)
        case invalidHost
        case invalidPort
        case invalidServerId
        case invalidFingerprint
    }

    init(host: String, port: UInt16, serverId: UUID, fingerprint: Data) {
        self.host = host
        self.port = port
        self.serverId = serverId
        self.fingerprint = fingerprint
    }

    init(url: URL) throws(ParseError) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == Self.scheme,
              components.host?.lowercased() == "pair",
              components.path.isEmpty || components.path == "/" else {
            throw .notPairingLink
        }

        // Each known item must appear exactly once: with two `fp` values the pinned
        // certificate would depend on which one a parser happens to pick.
        var values: [String: String] = [:]
        let known: Set<String> = ["v", "host", "port", "id", "fp"]
        for item in components.queryItems ?? [] where known.contains(item.name) {
            guard values[item.name] == nil else { throw .duplicate(item.name) }
            values[item.name] = item.value ?? ""
        }
        func value(_ name: String) throws(ParseError) -> String {
            guard let value = values[name] else { throw .missing(name) }
            return value
        }

        let version = try value("v")
        guard version == "2" else { throw .unsupportedVersion(version) }

        let host = try value("host")
        guard PrivateIPv4.isValid(host) else { throw .invalidHost }

        let rawPort = try value("port")
        guard !rawPort.isEmpty, rawPort.allSatisfy(\.isASCIIDigit),
              let port = UInt16(rawPort), port > 0 else { throw .invalidPort }

        guard let serverId = UUID(uuidString: try value("id")) else { throw .invalidServerId }

        guard let fingerprint = Self.fingerprintBytes(fromHex: try value("fp")) else { throw .invalidFingerprint }

        self.init(host: host, port: port, serverId: serverId, fingerprint: fingerprint)
    }

    /// Lowercase hex in groups of four, matching the Pair window on the PC.
    var groupedFingerprint: String {
        let hex = fingerprint.map { String(format: "%02x", $0) }.joined()
        return stride(from: 0, to: hex.count, by: 4).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return String(hex[start..<hex.index(start, offsetBy: 4)])
        }.joined(separator: " ")
    }

    /// Exactly 64 hex digits, either case; anything else is rejected rather than trimmed.
    static func fingerprintBytes(fromHex hex: String) -> Data? {
        let digits = Array(hex.utf8)
        guard digits.count == 64 else { return nil }
        var bytes = Data(capacity: 32)
        for index in stride(from: 0, to: 64, by: 2) {
            guard let high = hexValue(digits[index]), let low = hexValue(digits[index + 1]) else { return nil }
            bytes.append(high << 4 | low)
        }
        return bytes
    }

    private static func hexValue(_ digit: UInt8) -> UInt8? {
        switch digit {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): digit - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): digit - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): digit - UInt8(ascii: "A") + 10
        default: nil
        }
    }
}

/// The server only listens on a private IPv4 address (10/8, 172.16/12, 192.168/16).
nonisolated enum PrivateIPv4 {
    /// Dotted quad without leading zeros or extra characters, in a private range.
    static func isValid(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }) else {
            return false
        }
        let bytes = parts.compactMap { UInt8($0) }
        // Round-tripping rejects "010" and similar forms that parse but are ambiguous.
        guard bytes.count == 4, zip(parts, bytes).allSatisfy({ String($0.1) == String($0.0) }) else { return false }
        return bytes[0] == 10
            || (bytes[0] == 172 && (16...31).contains(bytes[1]))
            || (bytes[0] == 192 && bytes[1] == 168)
    }
}

nonisolated private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
