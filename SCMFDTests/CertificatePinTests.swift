import Foundation
import Security
import Testing
@testable import SCMFD

/// Self-signed P-256 certificates shaped like the server's (820 days, DNS SAN, CA:FALSE),
/// generated with OpenSSL 3.6.5 on 2026-10-27; valid until 2029-01-24.
struct CertificatePinTests {
    /// EKU serverAuth, like the CSMFD server certificate.
    static let server = "MIIBnjCCAUOgAwIBAgIUYwbR56PBAzB3KkRCcYkHRD37hpkwCgYIKoZIzj0EAwIwFzEVMBMGA1UEAwwMQ1NNRkQtU2VydmVyMB4XDTI2MTAyNzA0MjIxOVoXDTI5MDEyNDA0MjIxOVowFzEVMBMGA1UEAwwMQ1NNRkQtU2VydmVyMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEC+EnyS1ViHvGipfUGvoOvFH/PLk3GNJ3x70wgLsiEzGL+pf76kgBydaUE0n3ngUkX1iv3E8zu2qSeOhDgFgGwKNtMGswDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwEwFwYDVR0RBBAwDoIMY3NtZmQtc2VydmVyMB0GA1UdDgQWBBSFjc2B8mxjU4Dk4uh8ghe6tEur7jAKBggqhkjOPQQDAgNJADBGAiEA4rS/pBzYLCTsA/R8NQ0PyQhDIsLdptTTKn680LTtS5sCIQD3lNSklY3sNbXsl4aQ86hFWgStNNCu8iF6WoxUG/LdRg=="
    static let serverFingerprint = "923db4f5813a6a846d8767b1a3487073c0b89d056d8d92f22a9a79b61eeef0bd"

    /// EKU clientAuth only: must be refused even when its fingerprint is pinned.
    static let clientOnly = "MIIBnTCCAUOgAwIBAgIUDKTQjYxJAo3PnRDxnkF8WmOO8pYwCgYIKoZIzj0EAwIwFzEVMBMGA1UEAwwMQ1NNRkQtU2VydmVyMB4XDTI2MTAyNzA0MjIxOVoXDTI5MDEyNDA0MjIxOVowFzEVMBMGA1UEAwwMQ1NNRkQtU2VydmVyMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEqLmUmaF9bGMUIBpH4L1XlLYZTOL00EGdDSvlIw/sMvm+9PHeiM5zaQgZPQvG8+oPq8GaYTaQ4vU5pWZgy9JiCaNtMGswDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwIwFwYDVR0RBBAwDoIMY3NtZmQtc2VydmVyMB0GA1UdDgQWBBQSN5TThclYYYtFG/y88B2LjWGvbDAKBggqhkjOPQQDAgNIADBFAiBgpDvFtZPug/jxG8n++7T1N8KA71c+epNZftBsgRwg5AIhAOv+8KQfa5AmKbqO0sbQakUwz3gG7POzhl8afqSxC1Uj"
    static let clientOnlyFingerprint = "82517ad8335cf567dde082810d8489cfc01733d9b3892c3855c8c7042ab877d0"

    /// Inside the validity window of both certificates.
    static let validDate = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15

    private func certificate(_ base64: String) throws -> SecCertificate {
        let der = try #require(Data(base64Encoded: base64))
        return try #require(SecCertificateCreateWithData(nil, der as CFData))
    }

    /// A fresh trust object, as URLSession would hand over for one TLS handshake.
    private func trust(_ base64: String) throws -> SecTrust {
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(try certificate(base64), SecPolicyCreateSSL(true, nil), &trust)
        #expect(status == errSecSuccess)
        return try #require(trust)
    }

    private func bytes(_ hex: String) throws -> Data {
        try #require(PairingPayload.fingerprintBytes(fromHex: hex))
    }

    @Test func fingerprintMatchesOpenSSL() throws {
        #expect(CertificatePin.fingerprint(of: try certificate(Self.server)) == (try bytes(Self.serverFingerprint)))
    }

    @Test func pinnedServerCertificateIsAccepted() throws {
        try CertificatePin.verify(try trust(Self.server), expectedFingerprint: try bytes(Self.serverFingerprint), at: Self.validDate)
    }

    @Test func otherFingerprintIsRejected() throws {
        let trust = try trust(Self.server)
        let other = try bytes(Self.clientOnlyFingerprint)
        #expect(throws: CertificatePin.Failure.fingerprintMismatch) {
            try CertificatePin.verify(trust, expectedFingerprint: other, at: Self.validDate)
        }
    }

    @Test func clientOnlyCertificateIsRejectedEvenWhenPinned() throws {
        let trust = try trust(Self.clientOnly)
        let pinned = try bytes(Self.clientOnlyFingerprint)
        expectUntrusted { try CertificatePin.verify(trust, expectedFingerprint: pinned, at: Self.validDate) }
    }

    @Test(arguments: [
        Date(timeIntervalSince1970: 1_864_598_400), // 2029-02-01, after notAfter (2029-01-24)
        Date(timeIntervalSince1970: 1_792_972_800), // 2026-10-26, before notBefore (2026-10-27)
    ])
    func certificateOutsideValidityIsRejected(date: Date) throws {
        let trust = try trust(Self.server)
        let pinned = try bytes(Self.serverFingerprint)
        expectUntrusted { try CertificatePin.verify(trust, expectedFingerprint: pinned, at: date) }
    }

    // Plain `throws`: closure literals infer `any Error` and do not convert to typed throws.
    private func expectUntrusted(_ body: () throws -> Void, sourceLocation: SourceLocation = #_sourceLocation) {
        do {
            try body()
            Issue.record("Expected the certificate to be untrusted", sourceLocation: sourceLocation)
        } catch {
            guard case .untrusted = error as? CertificatePin.Failure else {
                Issue.record("Expected untrusted, got \(error)", sourceLocation: sourceLocation)
                return
            }
        }
    }
}
