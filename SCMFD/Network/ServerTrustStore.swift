import Foundation
import Security

/// The paired PC: where to connect, which certificate to expect and the token it issued.
nonisolated struct PairedServer: Codable, Sendable, Equatable {
    let serverId: UUID
    /// Last known address; may change without changing the server identity.
    var host: String
    var port: UInt16
    /// SHA-256 of the server's DER certificate, 32 bytes.
    let fingerprint: Data
    let token: String
}

/// Keeps the single paired server in the Keychain, on this device only.
/// One item holds everything, so address, fingerprint and token are always replaced together.
nonisolated struct ServerTrustStore: Sendable {
    nonisolated struct KeychainError: Error, Equatable {
        let status: OSStatus
    }

    private let service: String
    private let account = "paired-server"

    /// Tests pass their own service so they never touch the real pairing.
    init(service: String = "com.csmfd.app.server-trust") {
        self.service = service
    }

    func load() throws -> PairedServer? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(PairedServer.self, from: data)
    }

    /// Replaces the stored server. Update first, add only when missing: delete-then-add
    /// would lose the pairing if the app died in between.
    func save(_ server: PairedServer) throws {
        let data = try JSONEncoder().encode(server)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // ThisDeviceOnly: never synced to iCloud, never restored to another device.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError(status: status) }

        let addStatus = SecItemAdd(baseQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    /// Forget the pairing, e.g. after the server revoked this device.
    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
        ]
    }
}
