# Consent, Audit Log, Phân quyền & Bảo mật luồng chia sẻ dữ liệu — Góc nhìn Senior iOS

Đây là nhóm kiến thức thuộc **Data Governance & Privacy Engineering**, ngày càng quan trọng khi app xử lý dữ liệu cá nhân (health, finance, social…). Mình sẽ đi sâu từng phần.

---

## 1. Consent (Sự đồng ý của người dùng)

### Bản chất

Consent không chỉ là một popup "Agree" — nó là một **cơ chế pháp lý** (GDPR Art.7, CCPA, PDPA…) yêu cầu app phải:

- Thu thập sự đồng ý **trước** khi xử lý dữ liệu.
- Cho phép **rút lại** (withdraw) consent bất kỳ lúc nào.
- Ghi nhận **bằng chứng** rằng user đã đồng ý (ai, lúc nào, phiên bản policy nào).

### Triển khai trên iOS

**Consent Model** — lưu trữ trạng thái đồng ý:

```swift
struct ConsentRecord: Codable {
    let userID: String
    let consentType: ConsentType       // .analytics, .marketing, .dataSharing
    let granted: Bool
    let timestamp: Date
    let policyVersion: String          // "v2.3" — rất quan trọng
    let collectionMethod: String       // "in_app_prompt", "settings_toggle"
}

enum ConsentType: String, Codable {
    case analytics
    case marketing
    case thirdPartySharing
    case locationTracking
    case healthDataAccess
}
```

**Consent Gateway** — mọi luồng xử lý dữ liệu đều phải đi qua:

```swift
final class ConsentGateway {
    private let store: ConsentStore  // Keychain hoặc encrypted DB

    func isAllowed(_ type: ConsentType, for userID: String) -> Bool {
        guard let record = store.latestRecord(for: userID, type: type) else {
            return false  // Chưa có consent => mặc định KHÔNG cho phép
        }
        // Kiểm tra consent còn hiệu lực với policy version hiện tại
        return record.granted && record.policyVersion == PolicyManager.currentVersion
    }

    func grantConsent(_ type: ConsentType, for userID: String) {
        let record = ConsentRecord(
            userID: userID,
            consentType: type,
            granted: true,
            timestamp: Date(),
            policyVersion: PolicyManager.currentVersion,
            collectionMethod: "in_app_prompt"
        )
        store.save(record)
        AuditLogger.log(.consentGranted(record))   // ← gắn với audit log
        syncToBackend(record)                       // ← đồng bộ server
    }

    func revokeConsent(_ type: ConsentType, for userID: String) {
        // Tương tự nhưng granted = false
        // QUAN TRỌNG: trigger data deletion/anonymization pipeline
        DataRetentionManager.scheduleCleanup(for: userID, type: type)
    }
}
```

**Điểm senior cần lưu ý:**

- Khi policy version thay đổi → consent cũ **invalid**, phải re-prompt user. Đây là lý do cần lưu `policyVersion`.
- Consent phải được **sync server** vì đây là bằng chứng pháp lý, không chỉ lưu local.
- Tích hợp với `ATTrackingManager` (App Tracking Transparency) — đây là consent layer của Apple, nhưng app thường cần consent riêng chi tiết hơn.
- Thiết kế UI sao cho user có thể **granular control** (cho phép analytics nhưng từ chối marketing).

---

## 2. Audit Log (Nhật ký kiểm toán)

### Bản chất

Audit log ghi lại **ai đã làm gì, với dữ liệu gì, lúc nào** — phục vụ compliance, forensics, và debug security incidents.

### Thiết khai trên iOS

**Audit Event Model:**

```swift
struct AuditEvent: Codable {
    let id: UUID
    let timestamp: Date
    let actor: Actor                    // Ai thực hiện
    let action: AuditAction             // Làm gì
    let resource: AuditResource         // Với cái gì
    let result: ActionResult            // Thành công/thất bại
    let metadata: [String: String]      // Context bổ sung
    let deviceFingerprint: String       // Device ID, OS version...
    let sessionID: String
}

enum Actor {
    case user(id: String)
    case system(component: String)       // background job, sync engine
    case admin(id: String)
}

enum AuditAction: String, Codable {
    case viewedSensitiveData
    case exportedData
    case sharedData
    case modifiedPermission
    case consentGranted
    case consentRevoked
    case loginSuccess
    case loginFailed
    case tokenRefreshed
    case dataDeleted
}
```

**Audit Logger — Write-only, tamper-resistant:**

```swift
final class AuditLogger {
    private static let queue = DispatchQueue(label: "audit.log", qos: .utility)
    private static let encryptionKey = KeychainManager.getAuditKey()

    static func log(_ action: AuditAction, 
                    resource: AuditResource,
                    actor: Actor = .currentUser,
                    metadata: [String: String] = [:]) {
        queue.async {
            let event = AuditEvent(
                id: UUID(),
                timestamp: Date(),
                actor: actor,
                action: action,
                resource: resource,
                result: .success,
                metadata: metadata,
                deviceFingerprint: DeviceInfo.fingerprint,
                sessionID: SessionManager.currentSessionID
            )
            // 1. Encrypt trước khi lưu local
            let encrypted = try? CryptoManager.encrypt(event, key: encryptionKey)
            LocalAuditStore.append(encrypted)

            // 2. Batch upload lên server
            AuditSyncEngine.enqueue(event)
        }
    }
}
```

**Điểm senior cần lưu ý:**

- Audit log phải **append-only** — không bao giờ cho phép sửa/xoá trên client.
- Lưu local có mã hoá vì audit log chứa metadata nhạy cảm (ai xem gì, lúc nào).
- Batch sync lên server, dùng queue để không ảnh hưởng UX.
- Ghi log tại **mọi điểm truy cập dữ liệu nhạy cảm**, không chỉ user action mà cả system action (background sync, token refresh).
- Trong health/fintech app, auditor có thể yêu cầu truy xuất log trong vòng 72h — backend cần hỗ trợ query hiệu quả.

---

## 3. Phân quyền / Role-Based Access Control (RBAC)

### Bản chất

Kiểm soát **ai được xem/sửa/xoá gì** trong app. Đặc biệt quan trọng với app có multi-user, team, hoặc share data.

### Triển khai

**Permission Model:**

```swift
// Roles
enum Role: String, Codable {
    case owner           // Toàn quyền
    case editor          // Xem + sửa
    case viewer          // Chỉ xem
    case auditor         // Chỉ xem audit log
    case guest           // Truy cập giới hạn, có thời hạn
}

// Permissions gắn với resource cụ thể
struct Permission: Codable {
    let role: Role
    let resourceType: ResourceType     // .document, .folder, .healthRecord
    let resourceID: String
    let grantedBy: String              // UserID của người cấp quyền
    let expiresAt: Date?               // Quyền tạm thời
    let constraints: [Constraint]      // Điều kiện bổ sung
}

enum Constraint {
    case readOnly
    case noExport                       // Không cho tải/share ra ngoài
    case noScreenshot                   // Kích hoạt UIScreen.capturedDidChange
    case timeWindow(start: Date, end: Date)
    case ipRange(String)                // Dùng khi có corporate policy
}
```

**Access Control Enforcement:**

```swift
final class AccessControl {
    func canPerform(_ action: DataAction, 
                    on resource: ResourceIdentifier,
                    by user: UserContext) -> AccessDecision {
        // 1. Lấy permissions của user cho resource này
        let permissions = permissionStore.permissions(for: user.id, resource: resource)

        // 2. Kiểm tra role có đủ quyền không
        guard let permission = permissions.first(where: { $0.isActive }) else {
            AuditLogger.log(.accessDenied, resource: resource, actor: .user(id: user.id))
            return .denied(reason: .noPermission)
        }

        // 3. Kiểm tra constraints
        for constraint in permission.constraints {
            if !constraint.isSatisfied(action: action, context: user) {
                return .denied(reason: .constraintViolation(constraint))
            }
        }

        // 4. Check consent (phân quyền + consent là 2 layer khác nhau!)
        if resource.isSensitive && !consentGateway.isAllowed(.dataSharing, for: user.id) {
            return .denied(reason: .consentRequired)
        }

        AuditLogger.log(.accessGranted, resource: resource, actor: .user(id: user.id))
        return .allowed
    }
}
```

**Điểm senior cần lưu ý:**

- **RBAC thường nằm ở server** — client chỉ cache để hiển thị UI phù hợp (ẩn/hiện nút). Nhưng **enforce thật sự phải ở backend**. Client-side check chỉ là UX, không phải security.
- Kết hợp constraint-based access cho các trường hợp phức tạp (ví dụ: bác sĩ A chỉ xem hồ sơ bệnh nhân A trong giờ hành chính).
- Permission expiration — quan trọng cho tính năng share tạm thời.
- Luôn log mọi access decision (cả allowed và denied) vào audit log.

---

## 4. Bảo mật luồng chia sẻ dữ liệu (Secure Data Sharing Flow)

### Bản chất

Khi user share dữ liệu (qua link, cho người khác, cho hệ thống thứ 3), luồng này phải đảm bảo: đúng người nhận, đúng phạm vi, có thể thu hồi, có ghi log.

### Kiến trúc tổng thể

```
┌──────────────────────────────────────────────────────────────┐
│                    SECURE SHARING FLOW                        │
│                                                              │
│  ┌─────────┐    ┌──────────┐    ┌─────────┐    ┌─────────┐ │
│  │ Consent  │───▶│  Access   │───▶│  Data    │───▶│ Audit   │ │
│  │ Check    │    │  Control  │    │ Encrypt  │    │ Log     │ │
│  └─────────┘    └──────────┘    │ + Share  │    └─────────┘ │
│       │              │           └─────────┘         │       │
│       │              │               │               │       │
│  Consent denied? Access denied?  E2E encrypt    Log mọi     │
│  → Block + Log   → Block + Log   + expiry token  bước       │
└──────────────────────────────────────────────────────────────┘
```

### Triển khai Share Token

```swift
struct ShareToken: Codable {
    let id: String
    let resourceID: String
    let sharedBy: String
    let sharedWith: ShareTarget          // .user(id), .email, .link(public)
    let permissions: [SharePermission]   // .view, .download, .reshare
    let createdAt: Date
    let expiresAt: Date                  // BẮT BUỘC có thời hạn
    let maxAccessCount: Int?             // Giới hạn số lần mở
    let isRevoked: Bool

    var isValid: Bool {
        !isRevoked && Date() < expiresAt
    }
}

enum ShareTarget {
    case specificUser(id: String)
    case email(String)                   // Gửi invite link
    case publicLink                      // Ai có link đều xem được
}
```

**Sharing Service:**

```swift
final class SecureSharingService {

    func share(resource: ResourceIdentifier,
               with target: ShareTarget,
               permissions: [SharePermission],
               expiry: TimeInterval = 7 * 24 * 3600) -> Result<ShareToken, ShareError> {

        // 1. Consent check
        guard consentGateway.isAllowed(.thirdPartySharing, for: currentUser.id) else {
            AuditLogger.log(.shareDenied, reason: .consentMissing)
            return .failure(.consentRequired)
        }

        // 2. Permission check — user có quyền share resource này không?
        let access = accessControl.canPerform(.share, on: resource, by: currentUser)
        guard access == .allowed else {
            return .failure(.insufficientPermissions)
        }

        // 3. Tạo share token
        let token = ShareToken(
            id: UUID().uuidString,
            resourceID: resource.id,
            sharedBy: currentUser.id,
            sharedWith: target,
            permissions: permissions,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(expiry),
            maxAccessCount: 10,
            isRevoked: false
        )

        // 4. Nếu sensitive data → encrypt payload riêng cho recipient
        if resource.classification == .sensitive {
            let encryptedPayload = E2EEncryption.encrypt(
                resource.data,
                recipientPublicKey: target.publicKey
            )
            uploadEncryptedShare(encryptedPayload, token: token)
        }

        // 5. Audit log
        AuditLogger.log(.sharedData, resource: resource, 
                        metadata: ["target": target.description,
                                   "expiry": token.expiresAt.iso8601])

        return .success(token)
    }

    func revokeShare(_ tokenID: String) {
        shareStore.markRevoked(tokenID)
        AuditLogger.log(.shareRevoked, metadata: ["tokenID": tokenID])
        // Push notification hoặc real-time update cho recipient
    }
}
```

### Bảo vệ bổ sung trên iOS

```swift
// Chống screenshot khi hiển thị shared sensitive data
NotificationCenter.default.addObserver(
    forName: UIScreen.capturedDidChangeNotification, 
    object: nil, queue: .main
) { _ in
    if UIScreen.main.isCaptured {
        // Ẩn sensitive content, log sự kiện
        AuditLogger.log(.screenshotAttempt)
        sensitiveView.isHidden = true
    }
}

// Chặn copy/paste cho sensitive fields
class NoPasteTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) || action == #selector(copy(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
```

---

## 5. Kết nối toàn bộ — Tư duy kiến trúc

Một senior iOS cần thấy 4 thành phần này **không tách rời** mà tạo thành một pipeline:

```
User Action → Consent Check → RBAC Check → Execute → Audit Log
                  ↓                ↓            ↓          ↓
              Nếu thiếu:      Nếu denied:   Encrypt     Mọi bước
              Re-prompt UI    Show error    in transit   đều logged
              Block action    Hide UI       & at rest    (kể cả fail)
```

Nguyên tắc thiết kế:

- **Defense in depth**: Client kiểm tra để UX tốt, server kiểm tra để thực sự an toàn. Không bao giờ tin client.
- **Least privilege**: Mặc định không có quyền gì, phải được cấp rõ ràng.
- **Audit everything**: Mọi quyết định (cho phép lẫn từ chối) đều phải có log. Khi incident xảy ra, log là thứ duy nhất giúp truy vết.
- **Consent ≠ Permission**: User đồng ý chia sẻ dữ liệu (consent) khác với user có quyền thao tác (permission). Cần **cả hai** mới được thực thi.

Đây là kiến thức phân biệt một senior chỉ biết code UI với một senior có thể **thiết kế hệ thống an toàn từ đầu đến cuối**.
