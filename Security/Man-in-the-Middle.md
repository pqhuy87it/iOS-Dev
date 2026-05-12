# Phòng chống Man-in-the-Middle (MITM) trong iOS

## 1. Mô hình tấn công cần phòng chống

Trước khi nói về defense, cần xác định rõ MITM trong context mobile app gồm những kịch bản nào:

- **Public Wi-Fi attack**: attacker control router/AP, intercept traffic.
- **Rogue CA / Compromised CA**: attacker có cert hợp lệ ký bởi một CA mà device trust (ví dụ DigiNotar 2011, các MDM-installed root CA).
- **User-installed root CA**: user/enterprise cài root CA vào device → mọi cert ký bởi CA đó đều "hợp lệ" theo system trust store. Đây là cách mà Charles Proxy, mitmproxy, Burp hoạt động.
- **SSL stripping**: downgrade HTTPS → HTTP.
- **DNS spoofing** dẫn traffic về server giả mạo nhưng vẫn có cert "hợp lệ".

Mục tiêu: app chỉ tin cert/key của chính server thật, **không phụ thuộc vào system trust store**.

## 2. Layer 1 — App Transport Security (ATS)

ATS là bare minimum, được enforce ở mức URL Loading System. Mặc định từ iOS 9:

- Bắt buộc TLS 1.2+ (iOS 13+ recommend TLS 1.3)
- Forward secrecy
- SHA-256, RSA 2048-bit / ECC 256-bit trở lên
- Block HTTP cleartext

Trong `Info.plist`, **đừng** disable ATS toàn cục bằng `NSAllowsArbitraryLoads = YES`. Nếu cần exception (ví dụ legacy backend), chỉ exception cho specific domain:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy.example.com</key>
        <dict>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>
```

ATS chỉ chống được attacker chưa control một CA mà device trust. Nó **không** chống được rogue CA hoặc user-installed root CA → cần layer 2.

## 3. Layer 2 — Certificate Pinning

Đây là defense chính chống MITM. Có 3 kiểu pin, mỗi loại có trade-off khác nhau:

| Kiểu pin | Pin cái gì | Ưu | Nhược |
|---|---|---|---|
| Certificate pinning | Toàn bộ cert (DER) | Đơn giản | Cert renew là phải ship app mới |
| **Public key pinning (SPKI hash)** | Hash của SubjectPublicKeyInfo | Cert renew không cần update app (cùng keypair) | Cần backup pins |
| Intermediate CA pinning | Cert/key của intermediate | Linh hoạt nhất | Tin cả CA, weak hơn |

**Recommendation cho production**: **SPKI hash pinning** với ít nhất 2 pins (current + backup), giống như HPKP cũ và Chromium hiện vẫn dùng.

### 3.1. Generate SPKI hash

Lấy hash từ server cert (hoặc từ một key chưa deploy — đó chính là backup pin):

```bash
# Từ live server
openssl s_client -servername api.example.com -connect api.example.com:443 \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64

# Từ một cert file
openssl x509 -in cert.pem -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Output là một Base64 string dạng `sha256/AbCdEf...=`.

### 3.2. Implementation production-grade với URLSessionDelegate

```swift
import Foundation
import CryptoKit

final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    
    /// Map domain → tập SPKI hashes (current + backup pins)
    private let pinnedHashes: [String: Set<String>]
    
    init(pinnedHashes: [String: Set<String>]) {
        self.pinnedHashes = pinnedHashes
    }
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        guard let expectedHashes = pinnedHashes[host], !expectedHashes.isEmpty else {
            // Domain không có trong pin list → reject (fail-closed)
            // Hoặc tuỳ policy: cho phép default handling cho domain không pin
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 1. Trust evaluation chuẩn (chain validation, expiry, hostname...)
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 2. Pin verification: duyệt chain, nếu BẤT KỲ cert nào có SPKI hash match → pass
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        for cert in chain {
            if let spkiHash = Self.sha256SPKI(of: cert),
               expectedHashes.contains(spkiHash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        
        // Không có cert nào match → reject
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    /// Trích SubjectPublicKeyInfo (DER) từ cert và SHA256, encode Base64.
    private static func sha256SPKI(of certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        
        // Prepend ASN.1 header để có đúng SPKI DER, vì SecKeyCopyExternalRepresentation
        // trả về raw key, không phải SPKI. Header tuỳ vào key type.
        guard let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String,
              let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int,
              let header = Self.asn1Header(keyType: keyType, keySize: keySize) else {
            return nil
        }
        
        var spkiData = Data(header)
        spkiData.append(publicKeyData as Data)
        
        let hash = SHA256.hash(data: spkiData)
        return Data(hash).base64EncodedString()
    }
    
    private static func asn1Header(keyType: String, keySize: Int) -> [UInt8]? {
        // Bảng header phổ biến — đầy đủ xem TrustKit source
        switch (keyType, keySize) {
        case (kSecAttrKeyTypeRSA as String, 2048):
            return [0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a,
                    0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05,
                    0x00, 0x03, 0x82, 0x01, 0x0f, 0x00]
        case (kSecAttrKeyTypeRSA as String, 4096):
            return [0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a,
                    0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05,
                    0x00, 0x03, 0x82, 0x02, 0x0f, 0x00]
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 256):
            return [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48,
                    0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48,
                    0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00]
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 384):
            return [0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48,
                    0xce, 0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04,
                    0x00, 0x22, 0x03, 0x62, 0x00]
        default:
            return nil
        }
    }
}
```

Sử dụng:

```swift
let pinning = CertificatePinningDelegate(pinnedHashes: [
    "api.example.com": [
        "AbCdEf1234567890...=",   // current
        "ZyXwVu0987654321...="    // backup (key chưa deploy)
    ]
])

let session = URLSession(configuration: .ephemeral,
                        delegate: pinning,
                        delegateQueue: nil)
```

### 3.3. Vì sao phải pin SPKI chứ không phải cert?

- Cert có expiry (Let's Encrypt 90 ngày, public CA hiện max 398 ngày, sắp tới còn 47 ngày theo CA/B Forum proposal).
- Mỗi lần renew cert mà giữ nguyên private key → SPKI hash không đổi → app vẫn pass.
- Nếu pin cert, mỗi lần renew là phải release app mới — không thực tế.

### 3.4. Key rotation strategy

Đây là phần dễ làm sai và gây outage nhất:

1. **Luôn ship ≥ 2 pins**: pin hiện tại + ít nhất 1 backup pin của một keypair chưa deploy nhưng đã generate.
2. **Quy trình rotate**:
   - Generate keypair mới (backup-2), pre-compute SPKI hash.
   - Ship app version N với pins = [current, backup-1, backup-2].
   - Đợi version N đạt adoption đủ cao (ví dụ ≥ 95%, vài tuần).
   - Backend rotate cert sang backup-1 keypair.
   - Ship app version N+1 với pins = [backup-1, backup-2, backup-3].
3. **Không bao giờ rotate cert trước khi user đã update app** — đó là cách app bị brick hàng loạt.

### 3.5. Kill switch / remote config

Một best practice quan trọng nhưng nhạy cảm: cho phép **remote disable pinning** trong emergency (cert bị compromise và force rotate ngoài kế hoạch, hoặc bug trong pin list). Nhưng:

- Kill switch endpoint phải được pin **riêng** (hoặc dùng signed config).
- Nếu không, attacker MITM được endpoint kill switch → tắt pinning của chính họ → defeat the purpose.

Cách an toàn: ship một signed config (Ed25519 signature, public key compile-in), app verify signature trước khi apply. Cert/SPKI pin list cũng có thể được phân phối kiểu này.

## 4. Network framework (NWConnection) — modern approach

Với `Network.framework`, có thể custom verification ở level thấp hơn URLSession:

```swift
import Network

let options = NWProtocolTLS.Options()
sec_protocol_options_set_verify_block(
    options.securityProtocolOptions,
    { _, sec_trust, complete in
        let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
        // Apply same SPKI pinning logic on `trust`
        let valid = PinValidator.validate(trust, host: "api.example.com")
        complete(valid)
    },
    DispatchQueue.global()
)
```

Cách này phù hợp khi đang dùng `URLSession.WebSocketTask`, gRPC over Network.framework, hoặc raw TCP/TLS.

## 5. Các lớp phòng thủ bổ sung (defense in depth)

Pinning là main defense, nhưng nên kết hợp:

**a. Jailbreak detection** — không phải để block jailbroken user mà để giảm attack surface khi attacker có root trên device, có thể inject Frida hook `SecTrustEvaluateWithError`. Combine với `ptrace`/`sysctl` debugger detection (Huy đã làm).

**b. Anti-hooking cho pinning code** — Frida có thể bypass URLSessionDelegate bằng cách swizzle method. Mitigation:
- Implement pin check ở nhiều layer (Network.framework + URLSession).
- Detect `frida-server`, `cycript`, `objc_msgSend` hooks.
- Obfuscate pin hashes (ví dụ XOR với một key compile-time).

**c. App attestation** — `DCAppAttestService` (iOS 14+) để server verify app integrity. Không chống MITM trực tiếp nhưng làm replay/forge request khó hơn.

**d. Request signing với key ở Secure Enclave** — ECC P-256 key sinh trong SE, sign mỗi request. Attacker MITM lấy được payload nhưng không forge được signature mới (key không exportable). Bảo vệ tính toàn vẹn ngay cả khi TLS bị break.

**e. CertificateTransparency** — verify SCT trong cert. iOS có hỗ trợ một phần qua `kSecPolicyAppleSSLPolicyName`, nhưng app-level cần parse manually nếu muốn strict.

## 6. Common pitfalls

1. **Bật ATS exception sai cách**: dev bật `NSAllowsArbitraryLoads = YES` chỉ vì một domain test → production cũng bị disable ATS.
2. **Pin leaf cert mà không pin backup** → cert renew là app chết.
3. **Pin intermediate CA**: nhiều dev pin DigiCert/Let's Encrypt intermediate cho "tiện". Nếu attacker mua cert từ chính CA đó → bypass. Pin leaf SPKI là minimum.
4. **Không pin tất cả endpoints**: pin `api.example.com` nhưng quên `cdn.example.com`, `analytics.example.com`. Mỗi domain cấu hình pin riêng.
5. **`SecTrustEvaluateAsync` bị skip**: code cũ dùng `SecTrustEvaluate` (deprecated). Dùng `SecTrustEvaluateWithError` (iOS 12+).
6. **Test bị tắt pinning rồi ship production**: dùng compile-time flag (`#if DEBUG`) thay vì runtime, để release build không thể tắt.
7. **WebView không tin pinning**: `WKWebView` không gọi URLSessionDelegate. Phải implement `WKNavigationDelegate.webView(_:didReceive:completionHandler:)` riêng, hoặc proxy traffic qua native networking.

## 7. Testing & verification

- **Charles Proxy / mitmproxy với fake CA cài lên device** → app phải reject connection. Đây là smoke test bắt buộc trước mỗi release.
- **Test với cert sai (wrong key)** → reject.
- **Test với cert expired** → reject.
- **Test với backup pin** (chỉ ship backup, không có current trên server) → cần fail (vì current key vẫn đang serve).
- **Test rotation flow** trong staging environment trước khi rotate production.

Một script CI hữu ích: chạy app qua mitmproxy trong simulator, assert connection bị reject. Nếu pass → pin bị break.

## 8. Library hay tự build?

- **TrustKit**: battle-tested, dùng SPKI pinning, có reporting endpoint giống HPKP. Maintained, vẫn là lựa chọn an toàn nhất nếu không muốn tự maintain code crypto.
- **Alamofire `ServerTrustManager` + `PublicKeysTrustEvaluator`**: tiện nếu đã dùng Alamofire.
- **Tự build**: chỉ nên khi cần customize sâu (ví dụ pin từ remote signed config). Lưu ý ASN.1 header table phải đúng cho mọi key type backend dùng.

---

Nếu Huy đang triển khai trong một project cụ thể, có thể dive sâu hơn vào: integration với Alamofire/`URLSession`, key rotation playbook, hay cách build remote signed pin config. Phần nào muốn đi tiếp?
