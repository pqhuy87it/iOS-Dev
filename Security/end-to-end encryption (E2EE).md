## 1. Đọc câu này như một senior, không như một checklist

Câu trên là **JD/spec language** — nghe rất mạnh nhưng thực chất là ba yêu cầu độc lập bị gộp lại, và trong đó có một cái thường bị dùng sai:

| Cụm từ | Ý nghĩa kỹ thuật thực sự | Cạm bẫy |
|---|---|---|
| "high-level data security protocols" | Defense in depth: at rest / in transit / in use | Rất mơ hồ, dễ trở thành "đã dùng HTTPS là xong" |
| "E2EE" | **Server không có khả năng đọc plaintext** | 90% dự án nói E2EE nhưng thực chất chỉ là TLS + encryption at rest server-side |
| "strict privacy standards" | Nghĩa vụ pháp lý + Apple policy | Không phải bài toán code, mà là data governance |

Việc đầu tiên một senior làm không phải là chọn thuật toán, mà là **threat model**. Câu hỏi: *bạn đang phòng ai?*

- Attacker trên network (Wi-Fi công cộng, MITM) → TLS + pinning là đủ
- Attacker có thiết bị trong tay (máy mất, jailbroken) → Keychain ACL + Data Protection + Secure Enclave
- **Insider / server bị compromise / subpoena** → chỉ E2EE mới giải quyết được
- Attacker có quyền trên App Store build của bạn (reverse engineer) → obfuscation gần như vô nghĩa, đừng đặt secret trong client

Nếu không xác định rõ, bạn sẽ tiêu 3 sprint làm jailbreak detection (dễ bypass trong 5 phút) trong khi refresh token vẫn nằm trong `UserDefaults`.

---

## 2. Tầng 1 — Data at rest

### Keychain: attribute accessibility quan trọng hơn việc "dùng Keychain"

```swift
// SAI phổ biến: mặc định kSecAttrAccessibleWhenUnlocked
// → sync qua iCloud Keychain, restore được sang máy khác qua backup

let query: [String: Any] = [
    kSecClass as String:            kSecClassGenericPassword,
    kSecAttrService as String:      "vn.exchain.app.auth",
    kSecAttrAccount as String:      "refresh_token",
    kSecValueData as String:        tokenData,
    // ThisDeviceOnly: không sync iCloud, không nằm trong encrypted backup
    kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
]
SecItemAdd(query as CFDictionary, nil)
```

Chọn accessibility theo lifecycle thực tế:

- `WhenUnlockedThisDeviceOnly` — item chỉ dùng khi app foreground (session key)
- `AfterFirstUnlockThisDeviceOnly` — cần cho background task / silent push (bạn đã làm `BGTaskScheduler` nên biết: nếu chọn `WhenUnlocked`, background refresh sau reboot sẽ fail im lặng)
- `WhenPasscodeSetThisDeviceOnly` + `SecAccessControl` — item bắt buộc biometric

```swift
var error: Unmanaged<CFError>?
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],   // .biometryCurrentSet: đổi Face ID → key invalid
    &error
)!
```

`.biometryCurrentSet` vs `.biometryAny` là một quyết định security thật: `CurrentSet` invalidate key khi ai đó enroll thêm khuôn mặt/ngón tay — chống scenario "attacker biết passcode, tự thêm Face ID của mình".

### Secure Enclave: private key không bao giờ tồn tại trong app memory

```swift
let key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
// key.dataRepresentation KHÔNG phải private key
// nó là blob đã encrypt, chỉ SEP của đúng chiếc máy này giải được
let blob = key.dataRepresentation   // lưu blob này vào Keychain
```

Giới hạn phải nhớ khi thiết kế:

- Chỉ hỗ trợ **P-256** (`Signing` và `KeyAgreement`). Không có Ed25519, không có X25519, không có RSA.
- Key **không exportable** → không migrate được sang máy mới. Đây chính là lý do phần E2EE multi-device trở nên phức tạp (mục 4).
- Không phải nơi lưu data, chỉ là nơi giữ key.

### Encrypt payload bằng CryptoKit

```swift
// AEAD: vừa confidentiality vừa integrity. Đừng tự ghép AES-CBC + HMAC.
let sealed = try AES.GCM.seal(
    plaintext,
    using: symmetricKey,
    authenticating: Data("v1|user:\(userID)".utf8)  // AAD chống confused-deputy
)
let stored = sealed.combined!   // nonce || ciphertext || tag
```

Ba luật bất di bất dịch:

1. **Không bao giờ reuse nonce với cùng một key** trong GCM — nonce reuse làm lộ authentication key. `AES.GCM.seal` tự sinh random nonce, đừng tự truyền vào trừ khi bạn biết chính xác lý do.
2. Key **không bao giờ hardcode** trong source. Derive từ Keychain-stored key hoặc từ passphrase qua HKDF/PBKDF2 — không phải SHA256 của password.
3. Với data > vài MB, cân nhắc `ChaChaPoly` (nhanh hơn trên thiết bị không có AES-NI, nhưng iOS ARM có AES accelerator nên GCM thường vẫn thắng).

### File-level Data Protection

```swift
try data.write(to: url, options: [.atomic, .completeFileProtection])
// hoặc set cả directory
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.completeUnlessOpen],
    ofItemAtPath: dir.path
)
```

- `.completeFileProtection` → file **không đọc được khi máy lock**. Rất mạnh, nhưng sẽ crash/fail background write.
- `.completeUnlessOpen` → mở trước khi lock thì vẫn ghi được (dùng cho download queue).
- `.completeUntilFirstUserAuthentication` (default) → chỉ bảo vệ đến lần unlock đầu sau reboot.

Core Data / SQLite mặc định thừa hưởng protection class của file, nhưng WAL và `-shm` file cũng cần cùng class — dễ bị bỏ sót.

---

## 3. Tầng 2 — Data in transit

Bạn đã nắm ATS và pinning, nên tôi chỉ nhấn mấy điểm senior-level:

**Pin public key, không pin certificate.** Cert hết hạn ~1 năm; SPKI hash sống theo key. Luôn có **backup pin** (key dự phòng chưa deploy) — nếu không, ngày rotate cert bạn brick toàn bộ app đang chạy ngoài production và không có cách nào fix ngoài app update.

Declarative pinning (iOS 14+) tốt hơn `URLSessionDelegate` tự viết, vì bạn không thể vô tình implement sai `SecTrustEvaluate`:

```xml
<key>NSPinnedDomains</key>
<dict>
  <key>api.exchain.vn</key>
  <dict>
    <key>NSIncludesSubdomains</key><true/>
    <key>NSPinnedCAIdentities</key>
    <array>
      <dict><key>SPKI-SHA256-BASE64</key><string>primary...</string></dict>
      <dict><key>SPKI-SHA256-BASE64</key><string>backup...</string></dict>
    </array>
  </dict>
</dict>
```

Điều quan trọng nhất: **pinning bảo vệ chống MITM có CA hợp lệ, không bảo vệ chống chính server của bạn.** Nếu requirement là "server không được đọc data", pinning hoàn toàn vô ích. Đó là ranh giới giữa mục 3 và mục 4.

---

## 4. E2EE — phần khó thật sự, và nơi hầu hết dự án nói dối

**Định nghĩa nghiêm ngặt:** server chỉ nhìn thấy ciphertext và metadata. Không có bất kỳ đường nào để server, admin, hay bên thứ ba có subpoena đọc được nội dung. Nếu team bạn có tính năng "admin xem lại tin nhắn để hỗ trợ khách", **bạn không có E2EE** — hãy nói thẳng điều đó thay vì viết E2EE lên marketing.

### Bộ khung tối thiểu

```swift
// --- Identity: long-term key, sinh 1 lần khi register device
let identityKey = try SecureEnclave.P256.KeyAgreement.PrivateKey(accessControl: access)
// public key được upload + bind vào account

// --- Sender: derive per-message key
let ephemeral = P256.KeyAgreement.PrivateKey()
let ss = try ephemeral.sharedSecretFromKeyAgreement(with: recipientIdentityPub)

let messageKey = ss.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: conversationSalt,
    sharedInfo: Data("exchain-e2ee-v1|msg".utf8),   // domain separation
    outputByteCount: 32
)

let box = try AES.GCM.seal(plaintextJSON, using: messageKey)
// gửi lên server: ephemeral.publicKey.rawRepresentation + box.combined
```

Đây là ECIES cơ bản. Nhưng nó **chưa đủ** cho một sản phẩm thật, và đây là những gì bạn phải trả lời tiếp:

**a) Authentication.** Scheme trên không chứng minh ai là sender — bất kỳ ai có public key của recipient đều gửi được. Cần thêm signature bằng identity signing key, hoặc dùng 3-DH (X3DH) trộn identity key của cả hai phía.

**b) Forward secrecy & post-compromise security.** Nếu identity key bị lộ, toàn bộ tin nhắn cũ đã lưu đều giải mã được. Giải pháp là **Double Ratchet**: mỗi message advance một symmetric ratchet, mỗi round-trip advance một DH ratchet. Đây là hàng nghìn dòng code có state machine phức tạp (out-of-order message, skipped keys, session reset). **Đừng tự viết.** Dùng libsignal, hoặc chấp nhận scope nhỏ hơn và ghi rõ trong threat model.

**c) Multi-device — bài toán chí tử.** Vì Secure Enclave key không export được, mỗi thiết bị là một identity riêng. Nghĩa là:
- Mỗi message phải encrypt N lần cho N device của recipient (fan-out)
- Cần device list được server quản lý → server có thể **âm thầm thêm device của attacker** vào list. Chống lại việc này cần key transparency hoặc **safety number** cho user tự verify (Signal's model) — và phải chấp nhận rằng 99% user không verify.

**d) Backup / account recovery.** Đổi máy mà không mất history: cần một *recovery key* derive từ passphrase user nhớ (Argon2id/PBKDF2 với iteration cao), wrap master key, lưu blob trên server. Nếu bạn cho reset bằng SMS/email → **đó là backdoor**, E2EE mất ý nghĩa. Đây là trade-off business, không phải trade-off kỹ thuật, và phải được product owner ký.

**e) Những feature bạn buộc phải hy sinh:**

| Feature | Tình trạng dưới E2EE |
|---|---|
| Server-side full-text search | Mất. Chỉ search local, hoặc encrypted search index (rất phức tạp) |
| Push notification có nội dung | Chỉ gửi được placeholder, decrypt trong Notification Service Extension (extension phải truy cập được key → Keychain access group + `AfterFirstUnlock`) |
| Rich link preview server-side | Mất |
| Content moderation, analytics trên nội dung | Mất |
| Web version | Cần key trên browser → mô hình bảo mật yếu hơn nhiều |

**f) Metadata vẫn lộ.** Ai nói với ai, khi nào, tần suất, kích thước message. E2EE không giải quyết điều này. Nếu spec yêu cầu privacy nghiêm ngặt, phải nói rõ metadata nằm ngoài phạm vi (hoặc thiết kế sealed-sender).

---

## 5. Tầng 3 — Data in use (thường bị bỏ hoàn toàn)

Đây là nơi tôi tìm thấy nhiều lỗ nhất khi review code của team:

```swift
// OSLog: dynamic string là .private theo mặc định, nhưng số thì PUBLIC
logger.info("Login \(userID)")                  // userID: Int → LỘ ra sysdiagnose
logger.info("Login \(userID, privacy: .private)")
logger.info("Login \(email, privacy: .private(mask: .hash))")

// print() KHÔNG BAO GIỜ được đưa lên production build với PII
```

- **App switcher snapshot**: iOS chụp screenshot khi app vào background → che view sensitive ở `sceneWillDeignActive`/`applicationWillResignActive`
- **Screen recording**: `UIScreen.main.isCaptured` + notification `capturedDidChangeNotification` để blur nội dung
- **Pasteboard**: `UIPasteboard.general.setItems([...], options: [.localOnly: true, .expirationDate: Date()+60])` để không sync sang Mac qua Universal Clipboard
- **Crash reporter / analytics SDK**: Firebase Crashlytics, Sentry sẽ hút custom keys và breadcrumbs. Phải có scrubbing layer bắt buộc, không tin dev sẽ tự nhớ
- **Memory**: Swift `String`/`Data` không zero được đáng tin cậy (COW, copy ẩn). Nếu cần, dùng `SymmetricKey` (CryptoKit tự best-effort zeroize) hoặc buffer `UnsafeMutableRawBufferPointer` tự quản
- **Third-party SDK**: mỗi SDK là một attack surface có toàn quyền như app bạn. Đây là risk lớn hơn jailbreak detection nhiều lần

---

## 6. "Strict privacy standards" — phần này không phải bài toán code

### Bắt buộc từ phía Apple

- **`PrivacyInfo.xcprivacy`** (privacy manifest) — bắt buộc từ 2024. Phải khai:
  - `NSPrivacyAccessedAPITypes` + reason code cho các **required reason API**: `UserDefaults` (`CA92.1`), file timestamp, disk space, active keyboard, system boot time
  - `NSPrivacyTracking`, `NSPrivacyTrackingDomains` (domain nào tracking → bị chặn nếu user tắt ATT)
  - `NSPrivacyCollectedDataTypes` — phải khớp với App Privacy label
  - Third-party SDK phải có manifest **và signature** riêng
- **ATT** — `AppTrackingTransparency` nếu có tracking cross-app
- Purpose string trong Info.plist phải cụ thể, không viết "App cần quyền này"

### Nghĩa vụ pháp lý

Vì bạn ở VN và làm với partner Nhật, thực tế bạn đối mặt ba tầng:

- **Việt Nam**: Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân — yêu cầu **hồ sơ đánh giá tác động xử lý DLCN** gửi Bộ Công an (A05), consent phải rõ ràng và tách biệt, quy định riêng về chuyển dữ liệu ra nước ngoài. Cũng đã có Luật Bảo vệ dữ liệu cá nhân được thông qua siết chặt thêm — phần deadline và chi tiết cụ thể bạn nên xác nhận với bên legal vì các mốc thi hành có thay đổi.
- **Nhật (APPI / 個人情報保護法)**: partner Nhật thường yêu cầu 委託先管理 (quản lý nhà thầu), báo cáo 脆弱性診断 (vulnerability assessment) từ bên thứ ba, và điều khoản về 越境移転 (chuyển dữ liệu xuyên biên giới) — họ phải chứng minh được nơi data nằm.
- **GDPR/CCPA** nếu có user EU/California.

Điểm senior cần nắm: các luật này đòi hỏi những thứ **không có trong code**:

1. **Data minimization** — mọi field bạn collect phải có lý do. Cách rẻ nhất để compliant là không thu.
2. **Retention policy** — data tự xoá sau X ngày, có job thực thi và có log chứng minh.
3. **Right to erasure** — API xoá thật, kể cả trong backup và analytics. Với E2EE thì "xoá" thực chất là destroy key (crypto-shredding) — cách hợp lệ và rất gọn.
4. **Data residency** — server ở đâu, ai truy cập được.
5. **RoPA / DPIA** — tài liệu, không phải code.

---

## 7. Đưa vào engineering process

Security bị bào mòn qua từng PR nếu chỉ dựa vào ý thức. Cần cơ chế cứng:

- **CI gate**: `gitleaks`/`trufflehog` chặn secret trong commit; dependency scanning (`osv-scanner`) cho SPM/CocoaPods; SBOM
- **Secret management**: API key không nằm trong Info.plist hay `.xcconfig` commit vào repo. Và hiểu rằng *bất kỳ* secret trong client đều là public — kiến trúc phải giả định điều đó
- **PR checklist bắt buộc** cho code chạm data: accessibility class của Keychain item? có log PII không? crash reporter có scrub? file protection class?
- **Threat model là document sống**, review mỗi khi thêm feature chạm data
- **Third-party pentest** định kỳ — đặc biệt nếu partner Nhật sẽ yêu cầu báo cáo
- **Cryptographic agility**: version hoá mọi ciphertext (`v1|...`) từ ngày đầu để rotate được algorithm mà không phải migrate mù

---

## 8. Những câu bạn nên hỏi lại khi nhận requirement này

Đây mới là giá trị của một senior khi đọc dòng spec kia:

1. E2EE ở đây là *nghĩa chặt* (server không đọc được) hay chỉ là "encrypted at rest + TLS"? Ai ký quyết định này?
2. Có tính năng nào cần server đọc nội dung không (search, moderation, admin support, push có nội dung)? Nếu có, E2EE bị loại ngay từ requirement.
3. Multi-device có trong scope không? Nếu có, budget cho device verification và fan-out là bao nhiêu?
4. Account recovery: user quên passphrase thì mất data — business chấp nhận không?
5. Threat model chính thức là gì? Ai là adversary?
6. Metadata có được coi là sensitive không?
7. Data residency: server ở VN, JP hay cloud region nào? Ai có quyền production access?
8. Có yêu cầu audit/certification nào từ partner (ISO 27001, ISMS, pentest report)?

Nếu spec không trả lời được câu 1 và 2, thì dòng "Implement E2EE" đó chưa phải requirement — nó là một wish. Nhiệm vụ của bạn là biến nó thành requirement trước khi viết dòng code đầu tiên.
