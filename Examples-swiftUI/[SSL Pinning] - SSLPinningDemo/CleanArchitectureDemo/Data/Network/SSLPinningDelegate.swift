import Foundation
import CryptoKit

// MARK: - SSLPinningDelegate

/// URLSessionDelegate that enforces SSL pinning for configured domains.
///
/// Supports two pinning modes:
///   - .certificate: compare the server's DER certificate with a bundled .cer file
///   - .publicKey:   compare the SHA-256 hash of the server's SubjectPublicKeyInfo (SPKI)
///
/// To get the public key hash for a host, run:
///   openssl s_client -connect <host>:443 2>/dev/null \
///     | openssl x509 -pubkey -noout \
///     | openssl pkey -pubin -outform DER \
///     | openssl dgst -sha256 -binary \
///     | base64
final class SSLPinningDelegate: NSObject, URLSessionDelegate {

    enum PinningMode {
        /// Pin one or more DER-encoded certificates bundled as .cer files.
        case certificate(names: [String])
        /// Pin one or more SHA-256 hashes of the server's SubjectPublicKeyInfo (SPKI).
        case publicKey(hashes: [String])
    }

    private let pinnedDomains: [String: PinningMode]

    init(pinnedDomains: [String: PinningMode]) {
        self.pinnedDomains = pinnedDomains
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host

        guard let mode = pinnedDomains[host] else {
            // No pinning policy for this host — fall back to the OS's default validation.
            completionHandler(.performDefaultHandling, nil)
            return
        }

        switch mode {
        case .certificate(let names):
            validateCertificate(trust: serverTrust, certNames: names, completionHandler: completionHandler)
        case .publicKey(let hashes):
            validatePublicKey(trust: serverTrust, knownHashes: hashes, completionHandler: completionHandler)
        }
    }

    // MARK: - Shared helper

    private func serverCertificates(from trust: SecTrust) -> [SecCertificate] {
        if #available(iOS 15.0, *) {
            return (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        } else {
            return (0..<SecTrustGetCertificateCount(trust)).compactMap {
                SecTrustGetCertificateAtIndex(trust, $0)
            }
        }
    }
}

// MARK: - Certificate Pinning

extension SSLPinningDelegate {

    private func validateCertificate(
        trust: SecTrust,
        certNames: [String],
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        var cfError: CFError?
        guard SecTrustEvaluateWithError(trust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let pinnedCerts = loadBundledCertificates(names: certNames)
        guard !pinnedCerts.isEmpty else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverCerts = serverCertificates(from: trust)

        for serverCert in serverCerts {
            let serverData = SecCertificateCopyData(serverCert) as Data
            for pinnedCert in pinnedCerts where (SecCertificateCopyData(pinnedCert) as Data) == serverData {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    private func loadBundledCertificates(names: [String]) -> [SecCertificate] {
        names.compactMap { name in
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "cer"),
                let data = try? Data(contentsOf: url)
            else { return nil }
            return SecCertificateCreateWithData(nil, data as CFData)
        }
    }
}

// MARK: - Public Key Pinning

extension SSLPinningDelegate {

    private func validatePublicKey(
        trust: SecTrust,
        knownHashes: [String],
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        var cfError: CFError?
        guard SecTrustEvaluateWithError(trust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        for cert in serverCertificates(from: trust) {
            guard let hash = spkiHash(for: cert) else { continue }
            if knownHashes.contains(hash) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
        }

        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// Hashes the SubjectPublicKeyInfo (SPKI) of a certificate with SHA-256 and returns a base64 string.
    /// The SPKI = ASN.1 algorithm header + raw public key bytes.
    private func spkiHash(for certificate: SecCertificate) -> String? {
        guard
            let publicKey = SecCertificateCopyKey(certificate),
            let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
            let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any]
        else { return nil }

        let keyType = attributes[kSecAttrKeyType as String] as? String ?? ""
        let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int ?? 0

        guard let header = spkiHeader(keyType: keyType, keySize: keySize) else { return nil }

        var spki = Data(header)
        spki.append(keyData)

        let digest = SHA256.hash(data: spki)
        return Data(digest).base64EncodedString()
    }

    /// Returns the fixed ASN.1 SPKI header for a given key type/size combination.
    /// These bytes encode the algorithm OID; the raw key bytes are appended after.
    private func spkiHeader(keyType: String, keySize: Int) -> [UInt8]? {
        let rsa = kSecAttrKeyTypeRSA as String
        let ec  = kSecAttrKeyTypeEC  as String

        if keyType == rsa && keySize == 2048 {
            return [
                0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
                0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
                0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
            ]
        } else if keyType == rsa && keySize == 4096 {
            return [
                0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09,
                0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
                0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0f, 0x00
            ]
        } else if keyType == ec && keySize == 256 {
            // prime256v1 / P-256
            return [
                0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86,
                0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
                0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
                0x42, 0x00
            ]
        } else if keyType == ec && keySize == 384 {
            // secp384r1 / P-384
            return [
                0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86,
                0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b,
                0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
            ]
        }
        return nil
    }
}
