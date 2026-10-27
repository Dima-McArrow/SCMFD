import CryptoKit
import Foundation
import Security

/// Checks that the server presents exactly the certificate whose fingerprint came from the PC.
nonisolated enum CertificatePin {
    nonisolated enum Failure: Error, Equatable {
        case noCertificate
        case fingerprintMismatch
        /// The pinned certificate itself is not acceptable: expired, not yet valid or not for TLS servers.
        case untrusted(String)
    }

    /// SHA-256 of the DER certificate, the value shown on the PC and carried in the QR code.
    static func fingerprint(of certificate: SecCertificate) -> Data {
        Data(SHA256.hash(data: SecCertificateCopyData(certificate) as Data))
    }

    static func leafCertificate(of trust: SecTrust) -> SecCertificate? {
        (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
    }

    /// The fingerprint decides; the platform then checks validity dates and the serverAuth usage.
    /// `date` is injectable so expiry can be checked without an expired certificate.
    static func verify(_ trust: SecTrust, expectedFingerprint: Data, at date: Date = .now) throws(Failure) {
        guard let leaf = leafCertificate(of: trust) else { throw .noCertificate }
        guard fingerprint(of: leaf) == expectedFingerprint else { throw .fingerprintMismatch }

        // The pinned certificate is the only anchor, so no system root and no other self-signed
        // certificate can satisfy the check. No host name: the server is reached by IP while
        // its certificate names a DNS host; identity comes from the fingerprint instead.
        let statuses = [
            SecTrustSetPolicies(trust, SecPolicyCreateSSL(true, nil)),
            SecTrustSetAnchorCertificates(trust, [leaf] as CFArray),
            SecTrustSetAnchorCertificatesOnly(trust, true),
            SecTrustSetVerifyDate(trust, date as CFDate),
        ]
        guard statuses.allSatisfy({ $0 == errSecSuccess }) else { throw .untrusted("Trust configuration failed") }

        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            throw .untrusted(error.map { CFErrorCopyDescription($0) as String } ?? "Evaluation failed")
        }
    }
}

/// `URLSession` delegate that only accepts the pinned server certificate.
nonisolated final class PinnedTLSDelegate: NSObject, URLSessionDelegate, Sendable {
    nonisolated enum Mode: Sendable {
        /// Normal connection: continue only with this certificate fingerprint.
        case pinned(Data)
        /// Manual pairing: report the presented fingerprint and abort before any data is sent,
        /// so the user can compare it with the PC first.
        case captureFingerprint
    }

    private let mode: Mode
    private let onFingerprint: @Sendable (Data) -> Void
    private let onFailure: @Sendable (CertificatePin.Failure) -> Void

    init(
        mode: Mode,
        onFingerprint: @escaping @Sendable (Data) -> Void = { _ in },
        onFailure: @escaping @Sendable (CertificatePin.Failure) -> Void = { _ in }
    ) {
        self.mode = mode
        self.onFingerprint = onFingerprint
        self.onFailure = onFailure
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Only server trust is expected; client certificates or passwords are never offered.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return (.cancelAuthenticationChallenge, nil)
        }

        switch mode {
        case .captureFingerprint:
            if let leaf = CertificatePin.leafCertificate(of: trust) {
                onFingerprint(CertificatePin.fingerprint(of: leaf))
            } else {
                onFailure(.noCertificate)
            }
            return (.cancelAuthenticationChallenge, nil)
        case .pinned(let expected):
            do {
                try CertificatePin.verify(trust, expectedFingerprint: expected)
                return (.useCredential, URLCredential(trust: trust))
            } catch {
                onFailure(error)
                return (.cancelAuthenticationChallenge, nil)
            }
        }
    }
}
