import Foundation
import Security
import Testing
@testable import SCMFD

/// Runs against the real simulator Keychain with a unique service per test.
struct ServerTrustStoreTests {
    // Swift Testing runs tests in parallel on fresh instances, so each test gets its own item.
    private let service = "com.csmfd.tests.\(UUID().uuidString)"
    private var store: ServerTrustStore { ServerTrustStore(service: service) }

    private func server(host: String = "192.168.1.67", token: String = "token-1") -> PairedServer {
        PairedServer(
            serverId: UUID(),
            host: host,
            port: 47823,
            fingerprint: Data(repeating: 0xab, count: 32),
            token: token
        )
    }

    @Test func emptyStoreLoadsNil() throws {
        #expect(try store.load() == nil)
    }

    @Test func savedServerRoundTrips() throws {
        defer { try? store.delete() }
        let saved = server()
        try store.save(saved)
        #expect(try store.load() == saved)
    }

    @Test func secondSaveReplacesTheFirst() throws {
        defer { try? store.delete() }
        try store.save(server(token: "old"))
        let replacement = server(host: "192.168.1.80", token: "new")
        try store.save(replacement)
        #expect(try store.load() == replacement)
    }

    @Test func deleteForgetsAndIsIdempotent() throws {
        try store.save(server())
        try store.delete()
        #expect(try store.load() == nil)
        // Deleting again must not throw: revoke can arrive after a manual reset.
        try store.delete()
    }

    @Test func itemIsDeviceOnlyAndNotSynchronized() throws {
        defer { try? store.delete() }
        try store.save(server())
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "paired-server",
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Match synced items too, so a synced copy would be found and fail the check.
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        var result: CFTypeRef?
        #expect(SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess)
        let item = try #require(result as? [String: Any])
        #expect(item[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #expect((item[kSecAttrSynchronizable as String] as? Bool) != true)
    }
}
