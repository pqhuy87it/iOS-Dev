# Practical lab: MITM với Charles + SSL Pinning trên Unsplash API

Plan này rất chuẩn để hands-on học pinning. Tôi sẽ đi qua toàn bộ flow theo đúng thứ tự thực hành, kèm những điểm dễ vướng cụ thể với Unsplash.

## Tổng quan project

Sẽ build một app SwiftUI nhỏ gồm 2 build configuration / 2 toggle để so sánh trực tiếp:

| Phase | Pinning | Charles | Kết quả mong đợi |
|---|---|---|---|
| 1 | Off | Charles intercept | Đọc được toàn bộ request/response, thấy access key, JSON |
| 2 | On | Charles intercept | Connection reject ngay handshake, app báo network error |
| 3 | On | Charles tắt | Hoạt động bình thường |

So sánh 3 phase này mới thấy rõ pinning làm gì.

## Phase 0 — Chuẩn bị Charles + iPhone

**1. Bật Charles proxy server**
- Charles → `Proxy` → `Proxy Settings` → tab `Proxies` → ghi nhớ port (mặc định 8888).
- Bật `SSL Proxying`: `Proxy` → `SSL Proxying Settings` → tab `SSL Proxying` → enable → Add domain:
  - `api.unsplash.com:443`
  - `images.unsplash.com:443`
  - Hoặc dùng wildcard: `*.unsplash.com:443`

**2. iPhone kết nối qua Charles**
- iPhone và Mac cùng Wi-Fi.
- Settings → Wi-Fi → tap network → `Configure Proxy` → `Manual` → nhập IP Mac và port 8888.
- Trên Charles sẽ pop up `Allow` cho device → Allow.

**3. Install Charles Root Certificate**
- Trên iPhone, mở Safari → `chls.pro/ssl` → download profile.
- Settings → General → VPN & Device Management → install profile (cần passcode device).
- **Quan trọng** (chỗ hay quên): Settings → General → About → `Certificate Trust Settings` → enable full trust cho Charles cert. Bước này iOS 10.3+ bắt buộc, nếu không cert installed cũng không được trust cho SSL.

**4. Verify setup**
- Mở Safari iPhone → vào bất kỳ HTTPS site → trên Charles thấy traffic decrypt được (không phải `<- CONNECT>` raw bytes).

## Phase 1 — App không pinning, quan sát Charles

### Setup Unsplash

- Đăng ký developer account: `unsplash.com/developers` → tạo app → lấy **Access Key**.
- API endpoint chính: `https://api.unsplash.com/photos`
- Auth header: `Authorization: Client-ID YOUR_ACCESS_KEY`

### Project structure

```
UnsplashPinningDemo/
├── App/
│   └── UnsplashPinningDemoApp.swift
├── Networking/
│   ├── UnsplashClient.swift
│   ├── PinningDelegate.swift
│   └── PinningConfig.swift
├── Models/
│   └── Photo.swift
└── Views/
    └── PhotoListView.swift
```

### Models & Client (không pinning)

```swift
// Photo.swift
struct Photo: Decodable, Identifiable {
    let id: String
    let description: String?
    let urls: Urls
    
    struct Urls: Decodable {
        let small: String
        let regular: String
    }
}
```

```swift
// UnsplashClient.swift
import Foundation

final class UnsplashClient {
    private let accessKey: String
    private let session: URLSession
    private let baseURL = URL(string: "https://api.unsplash.com")!
    
    init(accessKey: String, pinningEnabled: Bool) {
        self.accessKey = accessKey
        
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        if pinningEnabled {
            let delegate = PinningDelegate(config: .unsplash)
            self.session = URLSession(configuration: config,
                                      delegate: delegate,
                                      delegateQueue: nil)
        } else {
            self.session = URLSession(configuration: config)
        }
    }
    
    func fetchPhotos(page: Int = 1) async throws -> [Photo] {
        var components = URLComponents(url: baseURL.appendingPathComponent("photos"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "20")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        
        let (data, response) = try await session.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Photo].self, from: data)
    }
}
```

### Chạy phase 1

- Khởi tạo với `pinningEnabled: false`.
- Build & run lên iPhone (đã set proxy + trust Charles cert).
- Trên Charles cửa sổ `Structure`, expand `api.unsplash.com` → sẽ thấy:
  - Request line, header `Authorization: Client-ID xxx` (lộ luôn access key!),
  - Response body JSON đầy đủ photos.
- Đây là minh chứng app **completely transparent** với attacker khi không có pinning.

Lưu ý: nếu Charles không decrypt được mà show raw bytes → thường do quên enable trust cert ở Certificate Trust Settings, hoặc chưa add domain vào SSL Proxying list.

## Phase 2 — Trích SPKI hash từ Unsplash

Tắt proxy iPhone trước khi extract (không thì lấy nhầm cert của Charles).

```bash
# api.unsplash.com
openssl s_client -servername api.unsplash.com -connect api.unsplash.com:443 </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64

# images.unsplash.com (nếu app load ảnh)
openssl s_client -servername images.unsplash.com -connect images.unsplash.com:443 </dev/null 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | openssl enc -base64
```

Output ví dụ: `K7r3Xz9Lm2qP5tYu...=`

**Gotcha cụ thể với Unsplash**: cả `api.unsplash.com` và `images.unsplash.com` đều phía sau CDN (Cloudflare/Imgix), nên:

1. Cert có thể rotate khá thường xuyên (cùng key hoặc khác key).
2. Mỗi connection có thể hit edge khác nhau, có khi nhận cert khác.
3. Trong lab này, nếu sau vài ngày app tự dưng fail → nhiều khả năng CDN rotate key. Đó cũng chính là lý do bạn phải có **backup pin** trong code production. Trong lab cứ extract lại hash mới.

Chạy command 2-3 lần cách nhau vài phút, nếu hash khác nhau → cert đang được rotate trên các edge → cần pin tất cả hash thấy được, hoặc switch sang chiến lược pin cấp intermediate CA (yếu hơn, nhưng phù hợp với CDN).

## Phase 3 — Implement pinning

```swift
// PinningConfig.swift
struct PinningConfig {
    let pinsByHost: [String: Set<String>]
    
    static let unsplash = PinningConfig(pinsByHost: [
        "api.unsplash.com": [
            "REPLACE_WITH_CURRENT_SPKI_HASH=",
            "REPLACE_WITH_BACKUP_SPKI_HASH="
        ],
        "images.unsplash.com": [
            "REPLACE_WITH_IMAGES_SPKI_HASH=",
            "REPLACE_WITH_BACKUP_SPKI_HASH="
        ]
    ])
}
```

```swift
// PinningDelegate.swift
import Foundation
import CryptoKit

final class PinningDelegate: NSObject, URLSessionDelegate {
    private let config: PinningConfig
    
    init(config: PinningConfig) {
        self.config = config
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
        guard let expectedPins = config.pinsByHost[host] else {
            // Host không nằm trong pin list → fail-closed (an toàn hơn cho lab)
            print("[Pinning] Reject: host \(host) not in pin list")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 1. Default trust evaluation (chain, expiry, hostname)
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            print("[Pinning] Reject: trust evaluation failed: \(String(describing: error))")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 2. Pin verification
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        for cert in chain {
            guard let hash = Self.sha256SPKI(of: cert) else { continue }
            if expectedPins.contains(hash) {
                print("[Pinning] Match for \(host): \(hash)")
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }
        
        // Log toàn bộ hash quan sát được — cực kỳ hữu ích để debug CDN rotation
        let observed = chain.compactMap { Self.sha256SPKI(of: $0) }
        print("[Pinning] Reject \(host). Observed pins: \(observed)")
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
    
    static func sha256SPKI(of certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }
        guard let attributes = SecKeyCopyAttributes(publicKey) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String,
              let keySize = attributes[kSecAttrKeySizeInBits as String] as? Int,
              let header = asn1Header(keyType: keyType, keySize: keySize) else {
            return nil
        }
        var spki = Data(header)
        spki.append(publicKeyData as Data)
        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }
    
    private static func asn1Header(keyType: String, keySize: Int) -> [UInt8]? {
        switch (keyType, keySize) {
        case (kSecAttrKeyTypeRSA as String, 2048):
            return [0x30,0x82,0x01,0x22,0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,
                    0xf7,0x0d,0x01,0x01,0x01,0x05,0x00,0x03,0x82,0x01,0x0f,0x00]
        case (kSecAttrKeyTypeRSA as String, 4096):
            return [0x30,0x82,0x02,0x22,0x30,0x0d,0x06,0x09,0x2a,0x86,0x48,0x86,
                    0xf7,0x0d,0x01,0x01,0x01,0x05,0x00,0x03,0x82,0x02,0x0f,0x00]
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 256):
            return [0x30,0x59,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,
                    0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,
                    0x42,0x00]
        case (kSecAttrKeyTypeECSECPrimeRandom as String, 384):
            return [0x30,0x76,0x30,0x10,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,
                    0x01,0x06,0x05,0x2b,0x81,0x04,0x00,0x22,0x03,0x62,0x00]
        default:
            return nil
        }
    }
}
```

### View để toggle pinning

```swift
// PhotoListView.swift
import SwiftUI

struct PhotoListView: View {
    @State private var pinningEnabled = false
    @State private var photos: [Photo] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    private let accessKey = "YOUR_UNSPLASH_ACCESS_KEY"
    
    var body: some View {
        NavigationStack {
            VStack {
                Toggle("SSL Pinning", isOn: $pinningEnabled)
                    .padding()
                
                Button("Fetch photos") {
                    Task { await fetch() }
                }
                .disabled(isLoading)
                
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .padding()
                }
                
                List(photos) { photo in
                    Text(photo.description ?? photo.id)
                }
            }
            .navigationTitle("Unsplash MITM Lab")
        }
    }
    
    private func fetch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        let client = UnsplashClient(accessKey: accessKey, pinningEnabled: pinningEnabled)
        do {
            photos = try await client.fetchPhotos()
        } catch {
            errorMessage = "\(error.localizedDescription)\n\((error as NSError).userInfo)"
        }
    }
}
```

## Phase 4 — Verify chống Charles

Chạy 3 kịch bản và quan sát console + Charles:

**Kịch bản A**: Pinning OFF, Charles ON
- Console: success, photos về.
- Charles: thấy full request/response.
- → Confirm MITM thành công khi không pin.

**Kịch bản B**: Pinning ON, Charles ON
- Console log: `[Pinning] Reject api.unsplash.com. Observed pins: ["xxx="]` — observed pin chính là SPKI của Charles dynamic-generated cert.
- App: `errSSLHandshakeFail` / `kCFURLErrorCannotConnectToHost`.
- Charles: thấy connection lập rồi bị TLS reset ngay, không decrypt được payload.
- → Pinning chặn MITM dù Charles cert đã được trust ở system level.

**Kịch bản C**: Pinning ON, Charles OFF (tắt proxy iPhone)
- Console log: `[Pinning] Match for api.unsplash.com: <real-hash>`.
- App: photos về bình thường.
- → Pinning không gây false-positive với traffic thật.

So sánh observed pin của Charles trong kịch bản B với pin thật trong kịch bản C — đó là minh hoạ trực quan nhất cho cơ chế: pinning so sánh public key của cert nhận được với whitelist, dù chain có "valid" theo system trust store hay không.

## Phase 5 — Mở rộng để học sâu hơn

Khi cơ bản đã chạy, có vài bài tập nên làm tiếp để hiểu hết edge cases:

1. **Thử pin sai hash cố ý** (đổi 1 ký tự) → quan sát app reject ngay cả khi Charles tắt → hiểu fail-closed behavior.
2. **Pin intermediate CA hash** thay vì leaf → bật Charles → kiểm tra xem có bypass được không (sẽ không, vì Charles dùng CA hoàn toàn khác). Nhưng nếu một CA thật khác phát hành cert cho cùng domain → bypass được → minh hoạ tại sao leaf pin > intermediate pin.
3. **Mô phỏng key rotation**: thêm 2 hash vào pin list, lấy 1 hash từ một domain khác (ví dụ `github.com`) làm "backup giả" → app vẫn pass với hash hợp lệ → hiểu OR logic giữa các pins.
4. **Bật pinning trong `WKWebView`**: nhúng `https://unsplash.com` → thấy pinning không apply → implement `WKNavigationDelegate` riêng.
5. **Thử Frida bypass** trên jailbroken device (nếu có): hook `URLSession(_:didReceive:completionHandler:)` để force `useCredential` → thấy pinning bị defeat → hiểu vì sao cần combine với anti-hooking.
6. **Network.framework version**: thử implement lại với `NWConnection` và `sec_protocol_options_set_verify_block` → compare 2 approach.

## Gotchas cụ thể cho lab này

- **Simulator**: dùng cert của Mac, không cần install Charles cert trên simulator nếu Mac đã trust Charles root. Nhưng physical device cho cảm giác realistic hơn.
- **Image loading**: `AsyncImage` dùng URLSession default → không pinning. Nếu muốn pin cả ảnh, phải custom image loader dùng cùng session.
- **Cache**: `URLCache` có thể trả response cũ làm bạn tưởng pinning đang work. Dùng `.ephemeral` config và clear cache giữa các test.
- **Background session**: nếu dùng `URLSessionConfiguration.background`, delegate auth challenge hoạt động khác — phase này skip background session để tránh nhiễu.
- **App Transport Security**: không cần đụng đến trong lab vì Unsplash dùng TLS 1.3 sạch.
- **`localizedDescription` của lỗi pinning** thường chỉ là "An SSL error has occurred" — không nói rõ là pinning fail. Lý do nên log observed hash trong delegate để debug.

---

Khi triển khai xong và muốn đi sâu hơn vào một phần — ví dụ Frida bypass, anti-hooking, hay chuyển sang Network.framework — cứ ping tiếp.
