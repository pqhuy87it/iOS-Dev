# Certificate Pinning & HTTP/2 Multiplexing trong iOS

## 1. Trước tiên — TLS Handshake hoạt động như thế nào?

Hiểu TLS là nền tảng để hiểu cả certificate pinning lẫn HTTP/2 multiplexing.

```
Client (iPhone)                              Server (api.example.com)
      │                                              │
      │─── 1. ClientHello ──────────────────────────▶│
      │    (TLS version, supported ciphers,          │
      │     random bytes)                            │
      │                                              │
      │◀── 2. ServerHello + Certificate ─────────────│
      │    (chosen cipher, server's public cert,     │
      │     certificate chain)                       │
      │                                              │
      │─── 3. Verify Certificate ───┐               │
      │    iOS kiểm tra:            │               │
      │    • Chain of trust ────────┤               │
      │    • Expiry date ───────────┤               │
      │    • Domain match ──────────┤               │
      │    • Revocation status ─────┘               │
      │                                              │
      │─── 4. Key Exchange ─────────────────────────▶│
      │    (pre-master secret, encrypted             │
      │     bằng server's public key)                │
      │                                              │
      │◀── 5. Finished ─────────────────────────────│
      │                                              │
      │◀══ 6. Encrypted Communication ══════════════▶│
      │    (symmetric encryption, cực nhanh)         │
      │                                              │
```

**Bước 3 là nơi certificate pinning can thiệp.** Mặc định iOS tin tưởng ~150+ root CA (Certificate Authority) được cài sẵn trong system trust store. Bất kỳ CA nào trong đó đều có thể issue certificate cho domain của bạn.

---

## 2. Certificate Pinning — Vấn đề cần giải quyết

### Tại sao default TLS chưa đủ?

```
Kịch bản tấn công Man-in-the-Middle (MITM):

                    Attacker
                   (proxy/WiFi)
                       │
  iPhone ──HTTPS──▶ Attacker ──HTTPS──▶ api.example.com
                       │
            Attacker dùng certificate giả
            được issue bởi CA mà device tin tưởng

Cách xảy ra:
  1. Corporate proxy cài CA cert lên device (MDM)
  2. User bị lừa cài malicious CA profile
  3. CA bị compromise (đã xảy ra: DigiNotar 2011, Symantec 2015)
  4. Government-issued CA dùng để surveillance
```

Khi attacker có certificate hợp lệ (được sign bởi trusted CA), iOS **không phát hiện được** vì chain of trust vẫn valid. Certificate pinning giải quyết điều này bằng cách: **app chỉ chấp nhận certificate cụ thể mà developer chỉ định**, bất kể CA nào issue.

### Pin cái gì?

```
Certificate Chain:

  ┌─────────────────────────┐
  │   Root CA Certificate   │  Pin ở đây: ít phải update nhất
  │   (DigiCert Root G2)    │  nhưng nếu CA bị compromise → xong
  └────────────┬────────────┘
               │ signs
  ┌────────────▼────────────┐
  │ Intermediate Certificate│  Pin ở đây: cân bằng tốt nhất ✅
  │ (DigiCert SHA2 Server)  │  Rotate ít, vẫn specific cho CA
  └────────────┬────────────┘
               │ signs
  ┌────────────▼────────────┐
  │   Leaf Certificate      │  Pin ở đây: bảo mật nhất
  │   (api.example.com)     │  nhưng cert renew = app update bắt buộc
  └─────────────────────────┘

Thực tế:
  • Pin Leaf → phải ship app update mỗi khi renew cert (1-2 năm)
  • Pin Intermediate → recommend, ít thay đổi, vẫn đủ specific
  • Pin Root → quá broad, hầu như không nên dùng
  • Pin Public Key (SPKI) thay vì cert → cert renew OK nếu giữ key pair
```

**Pin Public Key (Subject Public Key Info — SPKI) là best practice** vì khi server renew certificate nhưng giữ nguyên key pair, pin vẫn valid. Không cần force update app.

### Implementation 1: URLSessionDelegate (Manual)

```swift
class PinningSessionDelegate: NSObject, URLSessionDelegate {
    
    // SHA-256 hash của Subject Public Key Info (SPKI)
    // Lấy bằng: openssl x509 -in cert.pem -pubkey -noout |
    //           openssl pkey -pubin -outform DER |
    //           openssl dgst -sha256 -binary | base64
    private let pinnedHashes: Set<String> = [
        "abc123base64hash=",    // Primary cert
        "def456base64hash="     // Backup cert (QUAN TRỌNG!)
    ]
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod
                == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Bước 1: Verify certificate chain bình thường trước
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        SecTrustSetPolicies(serverTrust, policy)
        
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // Bước 2: Kiểm tra public key có match pin không
        let chainLength = SecTrustGetCertificateCount(serverTrust)
        
        for index in 0..<chainLength {
            guard let certificate = SecTrustCopyCertificateChain(serverTrust)
                    .map({ $0 as! [SecCertificate] })?[safe: index],
                  let publicKey = SecCertificateCopyKey(certificate),
                  let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil)
            else { continue }
            
            let hash = hashSPKI(keyData: publicKeyData as Data)
            
            if pinnedHashes.contains(hash) {
                // Match → cho phép connection
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // Không match pin nào → CHẶN connection
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    private func hashSPKI(keyData: Data) -> String {
        // ASN.1 header cho RSA 2048 public key
        // Header khác nhau tùy key type (RSA, EC) và key size
        let rsaHeader: [UInt8] = [
            0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09,
            0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
            0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
        ]
        
        var spkiData = Data(rsaHeader)
        spkiData.append(keyData)
        
        // SHA-256 hash
        let hash = SHA256.hash(data: spkiData)
        return Data(hash).base64EncodedString()
    }
}
```

### Implementation 2: App Transport Security (Declarative)

```xml
<!-- Info.plist — Apple's built-in pinning (iOS 14+) -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSPinnedDomains</key>
    <dict>
        <key>api.example.com</key>
        <dict>
            <!-- Pin intermediate CA's SPKI hash -->
            <key>NSPinnedCAIdentities</key>
            <array>
                <dict>
                    <key>SPKI-SHA256-BASE64</key>
                    <string>abc123base64hash=</string>
                </dict>
                <dict>
                    <!-- Backup pin -->
                    <key>SPKI-SHA256-BASE64</key>
                    <string>def456base64hash=</string>
                </dict>
            </array>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

**Ưu điểm ATS pinning:**

ATS xử lý ở tầng system, trước khi code của app chạy. Không thể bị bypass bởi runtime hook (khó hơn cho attacker dùng Frida/objection). Config declarative, ít bug hơn code tự viết.

**Nhược điểm:**

Chỉ hỗ trợ pin CA identity (intermediate/root), không pin leaf trực tiếp. Ít flexible hơn code approach.

### Backup Pin — Tại sao bắt buộc?

```
Kịch bản KHÔNG có backup pin:

  App ship với pin: "hash_A" (cert hiện tại)
  
  Server cert bị compromise → revoke → issue cert mới
  Cert mới có key pair mới → hash khác "hash_B"
  
  App vẫn chỉ chấp nhận "hash_A"
  → TOÀN BỘ user bị lock out
  → Phải ship emergency update
  → App Store review mất 1-3 ngày
  → 100% user không dùng được app trong thời gian đó

Kịch bản CÓ backup pin:

  App ship với: ["hash_A" (primary), "hash_B" (backup)]
  
  Backup key pair được generate sẵn, lưu offline an toàn
  Khi cần rotate → server dùng backup key pair
  → App tự động chấp nhận "hash_B"
  → Zero downtime
  → Ship update thêm pin mới cho lần rotate tiếp theo
```

---

## 3. HTTP/2 Multiplexing — Vấn đề cần giải quyết

### HTTP/1.1 — Head-of-Line Blocking

```
HTTP/1.1 với 1 TCP connection:

  Connection 1:
  ├─ Request A ────▶ ◻◻◻◻◻◻ Wait ◻◻◻◻◻◻ ◀── Response A ─┤
  ├─ Request B ────▶ ◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻ ◀── Response B ─┤  ← Blocked!
  ├─ Request C ────▶ ◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻◻ ◀── Resp C ─┤  ← Blocked!
  
  Workaround: mở nhiều TCP connection song song (thường 6)
  
  Connection 1: ──Req A──▶ ◻◻◻ ◀──Resp A──
  Connection 2: ──Req B──▶ ◻◻◻ ◀──Resp B──
  Connection 3: ──Req C──▶ ◻◻◻ ◀──Resp C──
  Connection 4: ──Req D──▶ ◻◻◻ ◀──Resp D──
  Connection 5: ──Req E──▶ ◻◻◻ ◀──Resp E──
  Connection 6: ──Req F──▶ ◻◻◻ ◀──Resp F──
  
  6 connection = 6 TLS handshake = 6× overhead
  Mỗi connection: ~1-2 RTT cho TCP + ~2 RTT cho TLS
  Trên 4G chậm (100ms RTT): 6 × ~400ms = ~2.4 giây chỉ cho setup
```

Mỗi TCP connection có **cost**: memory cho buffer, TLS handshake tốn CPU và latency, TCP slow start cần thời gian ramp up bandwidth. 6 connection đồng nghĩa nhân 6 tất cả.

### HTTP/2 — Multiplexing trên 1 connection

```
HTTP/2 với 1 TCP connection:

  Connection 1 (duy nhất):
  ┌──────────────────────────────────────────────────────┐
  │  Stream 1: ──▶ [frame][frame]     [frame] ◀──       │
  │  Stream 2: ──▶ [frame]   [frame][frame]   ◀──       │
  │  Stream 3: ──▶    [frame]  [frame]    [frame] ◀──   │
  │  Stream 4: ──▶ [frame][frame] [frame]        ◀──    │
  │                                                      │
  │  Tất cả interleaved trên cùng 1 TCP connection       │
  │  1 TLS handshake, 1 TCP slow start                   │
  └──────────────────────────────────────────────────────┘
```

### HTTP/2 — Cơ chế binary framing

```
HTTP/1.1 message (text-based):
  GET /api/users HTTP/1.1\r\n
  Host: api.example.com\r\n
  Authorization: Bearer xxx\r\n
  \r\n

HTTP/2 frame (binary):
  ┌─────────────────────────────────────┐
  │ Length (24 bit) │ Type (8) │ Flags  │  ← 9 bytes header
  │ Stream ID (31 bit)                  │  ← frame thuộc stream nào
  ├─────────────────────────────────────┤
  │              Payload                │
  │  (HEADERS frame hoặc DATA frame)   │
  └─────────────────────────────────────┘
  
  Stream 1: [HEADERS frame] → [DATA frame] [DATA frame]
  Stream 2: [HEADERS frame] → [DATA frame]
  
  Các frame từ nhiều stream được XEN KẼ trên 1 connection:
  
  Wire: [H:s1][H:s2][D:s1][D:s2][D:s1][D:s3][H:s3]...
         ↑      ↑     ↑     ↑
         Stream1 Stream2 interleaved freely
```

Mỗi request/response là một **stream** (identified by stream ID). Frames từ nhiều stream được interleave tự do. Không còn head-of-line blocking ở tầng HTTP — stream 2 không cần chờ stream 1 xong.

### HPACK — Header Compression

```
HTTP/1.1: mỗi request gửi lại TOÀN BỘ headers

  Request 1: Host: api.example.com
             Authorization: Bearer eyJhbGciOiJSUzI1NiIs...
             Accept: application/json
             Accept-Language: en-US
             User-Agent: MyApp/1.0

  Request 2: Host: api.example.com              ← lặp lại
             Authorization: Bearer eyJhbGciOiJSUzI1NiIs...  ← lặp lại
             Accept: application/json            ← lặp lại
             Accept-Language: en-US              ← lặp lại
             User-Agent: MyApp/1.0               ← lặp lại

  → ~500 bytes headers × 20 requests = 10 KB overhead

HTTP/2 HPACK: dùng dynamic table + Huffman encoding

  Request 1: [full headers, lưu vào table]
  
  Request 2: [index:1] [index:2] [index:3]
             ← Chỉ gửi index reference, vài bytes
             
  → ~500 bytes lần đầu, ~20 bytes các lần sau
  → Giảm ~95% header overhead
```

Đặc biệt có ý nghĩa khi mỗi request mang theo JWT token dài (thường 500-800 bytes) — với HTTP/2, token chỉ gửi full 1 lần.

### Server Push (HTTP/2)

```
Truyền thống:
  Client ──GET /feed──▶ Server
  Client ◀──JSON {imageURLs: [...]}── Server
  Client ──GET /img/1.webp──▶ Server    ← Mới bắt đầu download
  Client ──GET /img/2.webp──▶ Server
  
  = 2 round trips trước khi ảnh bắt đầu load

Server Push:
  Client ──GET /feed──▶ Server
  Client ◀──PUSH_PROMISE /img/1.webp── Server  ← Server đẩy luôn
  Client ◀──PUSH_PROMISE /img/2.webp── Server
  Client ◀──JSON {imageURLs: [...]}── Server
  Client ◀──DATA /img/1.webp── Server    ← Đã có sẵn!
  Client ◀──DATA /img/2.webp── Server
  
  = 1 round trip, ảnh arrive gần như cùng lúc với JSON
```

Tuy nhiên trong thực tế Server Push ít được dùng vì khó kiểm soát — server push resources mà client đã cache rồi → lãng phí. Hầu hết production system dùng `103 Early Hints` thay thế.

---

## 4. HTTP/2 trong iOS — URLSession

### URLSession hỗ trợ HTTP/2 tự động

```swift
// URLSession tự negotiate HTTP/2 qua ALPN trong TLS handshake
// Không cần config gì đặc biệt

let session = URLSession.shared

// Kiểm tra HTTP version được dùng
let (data, response) = try await session.data(from: url)
if let httpResponse = response as? HTTPURLResponse {
    // Không có API trực tiếp để check HTTP version
    // Dùng URLSessionTaskMetrics thay thế
}

// MARK: - Metrics để verify HTTP/2
class MetricsDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        for transaction in metrics.transactionMetrics {
            // "h2" = HTTP/2, "h3" = HTTP/3
            print("Protocol: \(transaction.networkProtocolName ?? "unknown")")
            
            // Connection reuse — key metric cho multiplexing
            print("Reused connection: \(transaction.isReusedConnection)")
            
            // Timing breakdown
            if let fetchStart = transaction.fetchStartDate,
               let connectEnd = transaction.connectEndDate,
               let responseEnd = transaction.responseEndDate {
                let connectionTime = connectEnd.timeIntervalSince(fetchStart)
                let totalTime = responseEnd.timeIntervalSince(fetchStart)
                print("Connection: \(connectionTime)s, Total: \(totalTime)s")
            }
        }
    }
}
```

### Multiplexing hoạt động tự động

```swift
// iOS tự multiplex requests đến cùng host qua 1 connection
// Chỉ cần fire nhiều request đồng thời

func loadFeed() async {
    // Tất cả dùng chung 1 TCP connection tới api.example.com
    async let profile = session.data(from: profileURL)
    async let feed = session.data(from: feedURL)
    async let notifications = session.data(from: notificationsURL)
    async let settings = session.data(from: settingsURL)
    
    // 4 requests multiplexed trên 1 connection
    // 1 TLS handshake thay vì 4
    let results = try await (profile, feed, notifications, settings)
}
```

### Khi multiplexing KHÔNG hoạt động

```swift
// ❌ Sai: dùng nhiều URLSession instance cho cùng host
let session1 = URLSession(configuration: .default)
let session2 = URLSession(configuration: .default)

// Mỗi session có thể tạo connection pool riêng
// → Không multiplex được giữa session1 và session2
Task { try await session1.data(from: apiURL1) }
Task { try await session2.data(from: apiURL2) }

// ✅ Đúng: dùng CHUNG 1 session cho cùng host
let sharedSession = URLSession(configuration: config)
Task { try await sharedSession.data(from: apiURL1) }
Task { try await sharedSession.data(from: apiURL2) }
// → Cùng connection pool, multiplexed
```

```swift
// ❌ Sai: ephemeral session cho mỗi request
func fetchData(url: URL) async throws -> Data {
    let session = URLSession(configuration: .ephemeral)
    let (data, _) = try await session.data(from: url)
    session.invalidateAndCancel()
    return data
}
// Mỗi lần gọi tạo session mới → connection mới → TLS mới

// ✅ Đúng: session sống lâu, reuse connection
class NetworkClient {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 1  // Force single connection
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    func fetch(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}
```

---

## 5. Kết hợp Certificate Pinning + HTTP/2

### Vấn đề tiềm ẩn

Certificate pinning can thiệp vào TLS handshake. Nếu implement sai, có thể phá vỡ HTTP/2 connection reuse.

```
Sai:
  Request 1 → TLS handshake → pin check ✅ → HTTP/2 connection established
  Request 2 → TẠO CONNECTION MỚI → TLS handshake → pin check ✅
  Request 3 → TẠO CONNECTION MỚI → TLS handshake → pin check ✅
  
  → Mỗi request 1 connection riêng
  → Mất hoàn toàn lợi ích multiplexing

Đúng:
  Request 1 → TLS handshake → pin check ✅ → HTTP/2 connection established
  Request 2 → REUSE connection ──────────→ multiplexed trên stream 2
  Request 3 → REUSE connection ──────────→ multiplexed trên stream 3
  
  → 1 connection, 1 handshake, N streams
```

### Implementation đúng cách

```swift
class SecureNetworkClient: NSObject {
    
    private let session: URLSession
    private let pinnedHashes: Set<String>
    
    init(pinnedHashes: Set<String>) {
        self.pinnedHashes = pinnedHashes
        
        let config = URLSessionConfiguration.default
        
        // Connection pool settings cho HTTP/2
        config.httpMaximumConnectionsPerHost = 1
        // ↑ Với HTTP/2 chỉ cần 1 connection
        // Nhiều hơn = nhiều TLS handshake = lãng phí
        
        // Cho phép HTTP pipelining (HTTP/2 dùng multiplexing thay thế)
        config.httpShouldUsePipelining = true
        
        // Reuse connection
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .useProtocolCachePolicy
        
        // Tạo session TRƯỚC, assign delegate SAU
        let tempSession = URLSession(configuration: config)
        self.session = tempSession
        super.init()
        
        // Reassign với delegate
        // LƯU Ý: phải tạo session mới vì URLSession.init(delegate:) 
        // cần delegate lúc init
    }
    
    // Convenience init thực tế
    static func create(pinnedHashes: Set<String>) -> SecureNetworkClient {
        let client = SecureNetworkClient(pinnedHashes: pinnedHashes)
        return client
    }
}

// MARK: - URLSessionDelegate
// Implement ở SESSION level, KHÔNG phải task level
// → Pin check 1 lần cho connection, reuse cho mọi request

extension SecureNetworkClient: URLSessionDelegate {
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Session-level challenge: áp dụng cho CONNECTION
        // Mọi request trên connection này đều được bảo vệ
        // Connection được reuse → multiplexing hoạt động bình thường
        
        guard challenge.protectionSpace.authenticationMethod
                == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        if validatePins(trust: trust) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            reportPinningFailure(host: challenge.protectionSpace.host)
        }
    }
    
    private func validatePins(trust: SecTrust) -> Bool {
        // Standard TLS validation trước
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else { return false }
        
        // Pin check — duyệt toàn bộ chain
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return false
        }
        
        return chain.contains { cert in
            guard let key = SecCertificateCopyKey(cert),
                  let keyData = SecKeyCopyExternalRepresentation(key, nil)
            else { return false }
            
            let hash = SPKIHash.sha256(keyData: keyData as Data)
            return pinnedHashes.contains(hash)
        }
    }
    
    private func reportPinningFailure(host: String) {
        // QUAN TRỌNG: log pin failure để detect MITM attempts
        // Gửi về analytics server (qua connection KHÁC, không pinned)
        print("⚠️ Certificate pinning failed for \(host)")
    }
}
```

### Session-level vs Task-level delegate

```
Session-level delegate (urlSession(_:didReceive:)):
  ┌─────────────────────────────────────────┐
  │  TLS Handshake → Pin Check → Connection │
  │         ↓          ↓            ↓       │
  │       1 lần      1 lần     Reused cho   │
  │                             mọi request │
  │                                         │
  │  Stream 1: ──request──▶ ◀──response──   │
  │  Stream 2: ──request──▶ ◀──response──   │
  │  Stream 3: ──request──▶ ◀──response──   │
  │         (multiplexing hoạt động ✅)      │
  └─────────────────────────────────────────┘

Task-level delegate (urlSession(_:task:didReceive:)):
  Có thể trigger authentication challenge cho MỖI task
  → Nếu handle sai, có thể force new connection per task
  → Phá vỡ multiplexing ❌
  
  Chỉ dùng task-level khi cần auth KHÁC NHAU cho từng request
  (ví dụ: client certificate auth cho specific endpoints)
```

---

## 6. Monitoring & Debug trong Production

### Đo lường hiệu quả multiplexing

```swift
class NetworkMetricsCollector: NSObject, URLSessionTaskDelegate {
    
    struct ConnectionMetrics {
        var totalRequests: Int = 0
        var reusedConnections: Int = 0
        var newConnections: Int = 0
        var h2Requests: Int = 0
        var h1Requests: Int = 0
        var totalHandshakeTime: TimeInterval = 0
    }
    
    private var metrics = ConnectionMetrics()
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting taskMetrics: URLSessionTaskMetrics
    ) {
        for tx in taskMetrics.transactionMetrics {
            metrics.totalRequests += 1
            
            // Connection reuse → multiplexing đang hoạt động
            if tx.isReusedConnection {
                metrics.reusedConnections += 1
            } else {
                metrics.newConnections += 1
                
                // Đo TLS handshake time
                if let secureStart = tx.secureConnectionStartDate,
                   let secureEnd = tx.secureConnectionEndDate {
                    metrics.totalHandshakeTime += secureEnd.timeIntervalSince(secureStart)
                }
            }
            
            // Protocol version
            switch tx.networkProtocolName {
            case "h2":    metrics.h2Requests += 1
            case "h3":    metrics.h2Requests += 1  // HTTP/3 cũng multiplexed
            default:      metrics.h1Requests += 1
            }
        }
    }
    
    func report() {
        let reuseRate = Double(metrics.reusedConnections) / Double(metrics.totalRequests) * 100
        print("""
        Connection Reuse Rate: \(reuseRate)%
        H2 Usage: \(metrics.h2Requests)/\(metrics.totalRequests)
        Avg Handshake: \(metrics.totalHandshakeTime / Double(metrics.newConnections))s
        Saved Handshakes: \(metrics.reusedConnections) × ~400ms
        """)
        
        // Target: reuse rate > 85% cho single-host API
        // Nếu thấp hơn → kiểm tra session lifecycle, connection timeout
    }
}
```

### Pin failure monitoring

```swift
// Đừng chỉ block connection — phải biết KHI NÀO pin fail xảy ra

struct PinningFailureReport: Codable {
    let host: String
    let timestamp: Date
    let expectedHashes: [String]
    let receivedChain: [String]  // Subject DN của mỗi cert trong chain
    let networkType: String      // WiFi vs Cellular
    let location: String?        // Country code — MITM phổ biến ở 1 số quốc gia
}

// Gửi report qua channel KHÔNG pinned (fallback endpoint)
// hoặc queue lại gửi sau khi có mạng khác
```

---

## 7. Tổng kết

```
┌─ Certificate Pinning ──────────────────────────────────┐
│                                                         │
│  Mục đích: Chống MITM khi attacker có valid cert        │
│                                                         │
│  Pin gì:   SPKI hash của Intermediate cert              │
│  Backup:   LUÔN có ≥ 2 pin (primary + backup key pair)  │
│  Cách pin: ATS (Info.plist) hoặc URLSessionDelegate     │
│  Monitor:  Log mọi pin failure, alert ops team          │
│  Rotate:   Plan trước, test trên staging                │
│                                                         │
│  ⚠ Rủi ro: Pin sai = lock out toàn bộ user              │
│     → Test kỹ, có kill switch (remote config)           │
└─────────────────────────────────────────────────────────┘

┌─ HTTP/2 Multiplexing ─────────────────────────────────┐
│                                                         │
│  Mục đích: Giảm connection overhead, tăng throughput    │
│                                                         │
│  Cách dùng: URLSession tự negotiate, chỉ cần đảm bảo   │
│   → 1 session instance cho cùng host                    │
│   → Session sống lâu, không tạo/hủy liên tục           │
│   → httpMaximumConnectionsPerHost = 1 cho HTTP/2        │
│                                                         │
│  Bonus:    HPACK header compression giảm ~95% overhead  │
│  Monitor:  URLSessionTaskMetrics.isReusedConnection     │
│                                                         │
│  ⚠ Trap: Tạo nhiều session = nhiều connection = mất     │
│     multiplexing                                        │
└─────────────────────────────────────────────────────────┘

┌─ Kết hợp cả hai ──────────────────────────────────────┐
│                                                         │
│  Pin check ở SESSION level delegate                     │
│  → 1 TLS handshake + 1 pin check                       │
│  → Connection được reuse cho mọi request                │
│  → Multiplexing hoạt động đầy đủ                        │
│                                                         │
│  Sai lầm phổ biến:                                      │
│  Pin ở task level → mỗi task trigger auth challenge     │
│  → Force new connection → phá vỡ multiplexing           │
└─────────────────────────────────────────────────────────┘
```

Điểm mấu chốt cho Senior: hai kỹ thuật này bổ trợ nhau — pinning tăng security, multiplexing tăng performance, và cả hai hoạt động trên **cùng 1 TLS connection**. Chìa khóa là implement pinning đúng tầng (session, không phải task) để không vô tình phá vỡ connection reuse mà HTTP/2 phụ thuộc vào.
