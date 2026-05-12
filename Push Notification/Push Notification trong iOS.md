# Push Notification trong iOS — Deep Dive

## 1. Architecture tổng thể

Push notification trong iOS xoay quanh **APNs (Apple Push Notification service)** — một dịch vụ trung gian do Apple vận hành, không bypass được. Hệ thống có 3 actors:

```
┌──────────────┐   HTTP/2 + JWT    ┌────────────┐   Persistent TLS   ┌──────────┐
│   Provider   │ ─────────────────► │   APNs     │ ─────────────────► │  Device  │
│   (Backend)  │                    │  (Apple)   │                    │ (iPhone) │
└──────────────┘                    └────────────┘                    └──────────┘
```

**Provider** (backend của bạn): chuẩn bị payload, ký JWT, gửi POST tới APNs endpoint qua HTTP/2.

**APNs**: nhận request, validate authentication, queue notification, push xuống device qua kết nối TLS dài hạn mà device đã thiết lập sẵn từ lúc boot.

**Device**: maintain persistent connection với APNs (do iOS quản lý, không phải app), nhận payload, đánh thức app phù hợp.

Điểm quan trọng senior cần nắm: **app KHÔNG kết nối trực tiếp với APNs**. iOS daemon (`apsd`) duy trì một kết nối duy nhất cho cả device, và route notification tới app dựa trên **device token**. Đây là lý do app không tốn battery duy trì connection riêng.

## 2. Authentication — Token-based vs Certificate-based

Có 2 cách provider authenticate với APNs:

**Token-based (JWT, .p8 key)** — recommended:
- Tạo Auth Key trong Apple Developer Portal → tải về file `.p8` (chỉ tải được 1 lần).
- Mỗi request, generate JWT signed bằng ES256 với key này.
- JWT có TTL ngắn (Apple khuyến nghị refresh mỗi ~30-60 phút, max 1 giờ).
- **1 key dùng được cho tất cả apps** trong cùng team.
- Không expire (trừ khi revoke), không cần renew như certificate.

JWT header + payload:
```json
// Header
{ "alg": "ES256", "kid": "ABC123DEFG" }   // kid = Key ID
// Payload
{ "iss": "TEAMID12345", "iat": 1700000000 }
```

**Certificate-based (.p12)** — legacy:
- Tạo APNs SSL Certificate per app trong Developer Portal.
- Export thành .p12, mount lên provider server.
- Expire sau 1 năm → phải renew manually.
- Tách biệt cert cho **sandbox** (dev/TestFlight) và **production**.

Trong dự án mới luôn chọn token-based. Cert-based chỉ giữ nếu có legacy infrastructure không migrate được.

## 3. Registration flow — Device Token lifecycle

```swift
// 1. Request permission
let center = UNUserNotificationCenter.current()
let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
guard granted else { return }

// 2. Register for remote notifications (phải gọi trên main thread)
await MainActor.run {
    UIApplication.shared.registerForRemoteNotifications()
}

// 3. AppDelegate callback nhận token
func application(_ app: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    // Gửi token lên backend
}

func application(_ app: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    // Network down, không có entitlement, profile sai...
}
```

**Device token có thể thay đổi**, không phải stable forever. Các trường hợp token rotate:
- User restore device từ backup
- User reinstall app
- User upgrade iOS version (đôi khi)
- App được migrate sang sandbox/production environment khác
- Apple tự rotate trong các trường hợp đặc biệt

→ App **phải gọi `registerForRemoteNotifications()` mỗi lần launch**, không cache token rồi skip. iOS sẽ cache và trả lại token cũ nếu chưa đổi (nhanh, không tốn network), hoặc trả token mới nếu rotated.

**Server-side**: token phải được lưu theo `(userId, deviceId)`, không chỉ `userId`. Một user có thể có nhiều device. Khi nhận token mới từ same device → update; khi APNs trả về error `Unregistered` (HTTP 410) → xoá token đó khỏi DB.

## 4. Payload structure — APS dictionary

Payload là JSON tối đa **4KB** cho notification thường, **5KB** cho VoIP push (mở rộng từ iOS 13). Quá size → APNs reject với `PayloadTooLarge`.

```json
{
  "aps": {
    "alert": {
      "title": "New message",
      "subtitle": "From John",
      "body": "Hey, are you free tonight?",
      "title-loc-key": "MSG_TITLE",
      "title-loc-args": ["John"],
      "loc-key": "MSG_BODY",
      "loc-args": ["John", "tonight"]
    },
    "badge": 5,
    "sound": {
      "critical": 1,
      "name": "alert.caf",
      "volume": 0.8
    },
    "thread-id": "conversation-42",
    "category": "MESSAGE_CATEGORY",
    "content-available": 1,
    "mutable-content": 1,
    "target-content-id": "post-123",
    "interruption-level": "time-sensitive",
    "relevance-score": 0.8,
    "filter-criteria": "work"
  },
  // Custom payload — app tự define
  "messageId": "msg-789",
  "senderId": "user-42",
  "encryptedBody": "base64...",
  "deepLink": "myapp://chat/42"
}
```

Các field đáng chú ý:

**`content-available: 1`** → silent push, đánh thức app trong background không hiện UI. Cần entitlement `remote-notification` trong Background Modes.

**`mutable-content: 1`** → cho phép Notification Service Extension intercept payload trước khi hiện. Bắt buộc nếu muốn download ảnh attachment, decrypt body, modify title.

**`interruption-level`** (iOS 15+):
- `passive` — không hiện banner, chỉ vào Notification Center (cho update không quan trọng).
- `active` — default, hiện banner thường.
- `time-sensitive` — bypass Focus Mode (cần entitlement `com.apple.developer.usernotifications.time-sensitive`).
- `critical` — bypass cả silent mode + DND (rất hạn chế, phải apply Apple approval, dùng cho safety/health alerts).

**`relevance-score`** (0.0-1.0): iOS dùng để chọn notification nào hiện trong **Notification Summary** (iOS 15+ feature). Score cao = nổi bật hơn.

**`thread-id`** → group các notification cùng conversation. Notification Center sẽ stack chúng lại.

**`target-content-id`** → match với scene identifier trong app, giúp iOS biết nên route tới scene nào (multi-window iPad).

## 5. Các loại notification

| Loại | Trigger | Visible? | Use case |
|---|---|---|---|
| **Alert** | `alert` field | ✅ | Message, notification thường |
| **Silent (background)** | `content-available: 1`, không `alert` | ❌ | Sync data, refresh cache, trigger background fetch |
| **Mutable** | `mutable-content: 1` | ✅ | Decrypt E2E, attach image/video |
| **Provisional** | Quyền `.provisional` | ✅ (quiet delivery vào Notification Center) | Onboarding-free notification, không cần xin permission |
| **Time Sensitive** | `interruption-level: time-sensitive` | ✅ (bypass Focus) | Reminder, ride sharing, food delivery |
| **Critical** | `interruption-level: critical` + sound `critical: 1` | ✅ (bypass DND, silent mode) | Health/safety alerts (cần Apple approval) |
| **Communication** | INSendMessageIntent donation | ✅ (avatar người gửi) | Chat, VoIP |
| **VoIP (PushKit)** | PKPushRegistry, CallKit | ✅ (incoming call UI) | Voice/video call |
| **Live Activity** | ActivityKit + push token riêng | ✅ (Dynamic Island, Lock Screen) | Live sports, delivery tracking |

## 6. Notification Service Extension — Intercept & modify

Service Extension là một target riêng (`NotificationService`) chạy trong process tách biệt với app. Khi payload có `mutable-content: 1`, iOS launch extension này **trước khi hiển thị notification**, cho ta ~30 giây để modify content.

```swift
class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
        
        guard let content = bestAttemptContent else { return }
        
        // 1. Decrypt body nếu E2E encrypted
        if let encrypted = content.userInfo["encryptedBody"] as? String {
            content.body = decrypt(encrypted) ?? "New message"
        }
        
        // 2. Download attachment ảnh
        if let imageUrlString = content.userInfo["imageUrl"] as? String,
           let imageUrl = URL(string: imageUrlString) {
            downloadAttachment(from: imageUrl) { attachment in
                if let attachment = attachment {
                    content.attachments = [attachment]
                }
                contentHandler(content)
            }
        } else {
            contentHandler(content)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Hết 30s — phải gọi handler với content tốt nhất hiện có
        if let handler = contentHandler, let content = bestAttemptContent {
            handler(content)
        }
    }
}
```

Use case quan trọng:
- **E2E encrypted messaging**: server gửi ciphertext, extension decrypt với key trong **Keychain shared App Group**.
- **Rich media**: download ảnh/video attachment.
- **Localization runtime**: thay đổi text theo locale của device.
- **Filtering**: drop notification dựa trên local state (vd: đã đọc message rồi).

**Limitation**: Service Extension không share memory với app, phải dùng **App Group** + Keychain shared để truy cập common state. Networking giới hạn (~30s), không được làm task nặng.

## 7. Notification Content Extension — Custom UI

Khác với Service Extension chỉ modify data, **Content Extension** cho phép define **custom UI** khi user expand notification (long-press hoặc swipe).

- Tạo target `Notification Content Extension`.
- Define `UNNotificationExtensionCategory` trong Info.plist match với `category` trong payload.
- Implement `UIViewController` conform `UNNotificationContentExtension`.
- Có thể hiện map, video player, custom controls.

Dùng cho: rich preview của post, live score, map ride tracking. Hạn chế: không tương tác phức tạp, chỉ display + một số action định trước.

## 8. Categories & Interactive Actions

Cho phép user respond ngay trong notification mà không cần mở app.

```swift
// Register categories khi app launch
let replyAction = UNTextInputNotificationAction(
    identifier: "REPLY_ACTION",
    title: "Reply",
    options: [],
    textInputButtonTitle: "Send",
    textInputPlaceholder: "Type a message..."
)

let likeAction = UNNotificationAction(
    identifier: "LIKE_ACTION",
    title: "❤️ Like",
    options: [.authenticationRequired]  // require Face ID/passcode
)

let muteAction = UNNotificationAction(
    identifier: "MUTE_ACTION",
    title: "Mute",
    options: [.destructive]
)

let category = UNNotificationCategory(
    identifier: "MESSAGE_CATEGORY",
    actions: [replyAction, likeAction, muteAction],
    intentIdentifiers: [],
    options: [.customDismissAction, .hiddenPreviewsShowTitle]
)

UNUserNotificationCenter.current().setNotificationCategories([category])
```

Payload trigger:
```json
{ "aps": { "alert": "...", "category": "MESSAGE_CATEGORY" } }
```

Handle response:
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    switch response.actionIdentifier {
    case "REPLY_ACTION":
        if let textResponse = response as? UNTextInputNotificationResponse {
            let userText = textResponse.userText
            // Send reply
        }
    case "LIKE_ACTION":
        // Send like
    case UNNotificationDefaultActionIdentifier:
        // User tap notification body
        handleDeepLink(response.notification.request.content.userInfo)
    case UNNotificationDismissActionIdentifier:
        // User dismiss notification (cần option .customDismissAction)
    default: break
    }
    completionHandler()
}
```

## 9. Foreground vs Background handling

Khi notification đến, hành vi phụ thuộc app state:

**Foreground** — mặc định **không tự hiện banner**. Phải implement:
```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent notification: UNNotification,
                            withCompletionHandler completionHandler: 
                                @escaping (UNNotificationPresentationOptions) -> Void) {
    // iOS 14+: dùng .banner thay vì .alert (deprecated)
    completionHandler([.banner, .sound, .badge, .list])
}
```

Có thể decide theo context: nếu user đang trong chat với A, đừng hiện notification từ A.

**Background (suspended/terminated)** — iOS xử lý tự động, app không nhận callback cho đến khi user tap.

**User tap notification** → `didReceive response:` được gọi. Nếu app đang killed → cold launch, callback đến **sau khi** `didFinishLaunching` xong (nên init UI sẵn sàng route).

**Silent push (background)** → AppDelegate callback:
```swift
func application(_ application: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                 fetchCompletionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Có ~30s để làm việc (download, sync)
    Task {
        await syncData()
        fetchCompletionHandler(.newData)
    }
}
```

## 10. Cold start từ notification

Tương tự deep link, khi user tap notification và app đang killed:

```swift
func application(_ app: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: ...) -> Bool {
    if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
        // App được launch từ tap notification
        // Queue lại để xử lý sau khi root VC ready
        NotificationCoordinator.shared.pendingNotification = userInfo
    }
    return true
}
```

Pattern giống `DeepLinkCoordinator`: queue → app ready → replay → route. Đừng cố navigate ngay trong `didFinishLaunching` vì window/rootViewController chưa attach.

## 11. Server-side concerns

**HTTP/2 endpoint**:
- Sandbox: `https://api.sandbox.push.apple.com:443`
- Production: `https://api.push.apple.com:443`

Endpoint: `POST /3/device/{deviceToken}`

**Headers quan trọng**:
- `authorization: bearer <JWT>` — token auth
- `apns-topic: <bundleId>` — bundle ID của app (hoặc `bundleId.voip`, `bundleId.complication`...)
- `apns-push-type` — bắt buộc từ iOS 13+: `alert`, `background`, `voip`, `location`, `complication`, `fileprovider`, `mdm`, `liveactivity`
- `apns-priority`:
  - `10` — gửi ngay (default cho alert)
  - `5` — gửi tiết kiệm pin (bắt buộc cho silent push, nếu không APNs sẽ throttle hoặc drop)
  - `1` — for low priority background updates (iOS 17+)
- `apns-expiration` — Unix timestamp, nếu device offline đến time này thì discard. `0` = chỉ thử 1 lần.
- `apns-collapse-id` — group notification, mới sẽ replace cũ chưa hiện. Max 64 bytes.
- `apns-id` — UUID để track, server có thể tự generate hoặc Apple generate.

**Response codes**:
- `200` — delivered to APNs (KHÔNG đồng nghĩa delivered to device).
- `400` — bad request (payload invalid).
- `403` — auth fail (JWT expired/sai key).
- `410` — token unregistered → **xoá token khỏi DB ngay**.
- `413` — payload too large.
- `429` — too many requests cho cùng device.
- `500/503` — APNs server issue, retry với exponential backoff.

## 12. Silent push — Caveats nghiêm trọng

Silent push **không guaranteed delivery**. Apple throttle dựa trên:
- App có frequently abusing không (chỉ dùng để wake app, không hiện UI cho user).
- Battery state, Low Power Mode.
- Background app refresh setting của user.
- Device state (Sleep, Focus).

iOS có thể delay, coalesce, hoặc **drop hoàn toàn** silent push. Best practices:
- Set `apns-priority: 5` (bắt buộc), nếu không Apple drop.
- Set `apns-push-type: background`.
- Đừng spam — Apple tracks pattern, app abuse có thể bị throttle vĩnh viễn.
- Không dùng silent push cho mission-critical (vd: trigger sync important data). Dùng kết hợp với BackgroundTasks framework để fallback.
- Test trên device thật, không chỉ Simulator.

## 13. Provisional Authorization

Từ iOS 12, có thể request quyền `.provisional`:
```swift
center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
```

→ Không hiện permission prompt. Notification được deliver **quiet** (chỉ vào Notification Center, không banner, không sound). User có thể upgrade thành full khi pull-down notification và chọn "Keep" hoặc "Turn Off".

Use case: onboarding-free messaging app, news app — user trải nghiệm trước, decide sau.

## 14. Focus Modes & Time Sensitive (iOS 15+)

Từ iOS 15, **Focus Mode** thay thế Do Not Disturb với phân loại tinh hơn. Mặc định notification thường bị suppress trong Focus, **chỉ time-sensitive bypass được**.

Để gửi time-sensitive:
1. Thêm entitlement `com.apple.developer.usernotifications.time-sensitive` trong Capabilities.
2. Set `interruption-level: time-sensitive` trong payload.
3. User vẫn có thể tắt time-sensitive cho app trong Settings.

Communication notifications (từ INSendMessageIntent donation) cũng bypass được Focus nếu user đã allow contact đó.

## 15. Live Activities & Broadcast Push

**Live Activities** (iOS 16.1+) là UI persistent trên Lock Screen + Dynamic Island, update qua push token **riêng biệt** với device token thường:

```swift
let activity = try Activity<DeliveryAttributes>.request(
    attributes: attributes,
    contentState: initialState,
    pushType: .token  // request push token cho activity này
)

for await tokenData in activity.pushTokenUpdates {
    let token = tokenData.map { String(format: "%02x", $0) }.joined()
    // Gửi token này lên server, dùng để update activity từ remote
}
```

Server gửi update qua APNs với `apns-push-type: liveactivity` và topic `<bundleId>.push-type.liveactivity`. Payload có `content-state` để update UI.

**Broadcast Push** (iOS 16.4+, Channels) cho **Push to Talk** apps — gửi tới nhiều device cùng lúc trong cùng channel, dùng APNs Channels API.

## 16. Pitfalls thường gặp ở production

**Token environment mismatch**: TestFlight/Debug build dùng sandbox APNs, App Store build dùng production. Token KHÁC NHAU giữa hai env, không tương thích. Server phải route đúng endpoint dựa trên build env.

**Token rotation không handle**: User đổi device, token cũ vẫn trong DB → notification không tới + tốn API call. Phải:
- App gọi `registerForRemoteNotifications()` mỗi launch.
- Server xử lý 410 Unregistered → xoá token.
- Refresh token định kỳ (vd: weekly check-in).

**Quên `mutable-content` khi cần Service Extension**: Extension không trigger → image không hiện → ciphertext lộ ra body.

**Silent push không tới**: Quên set priority 5, hoặc abuse → bị throttle. Hoặc user tắt Background App Refresh.

**Foreground không hiện banner**: Quên implement `willPresent`, mặc định iOS không hiện khi app active.

**Badge count tự increment**: Payload `"badge": 1` set tuyệt đối, không tăng từ giá trị hiện tại. Phải **server tự count unread** và gửi số đúng.

**Race condition cold start**: Tap notification → app launch → cố navigate ngay trong `didFinishLaunching` → crash vì rootVC chưa ready. Phải queue + replay sau.

**Payload chứa PII**: APNs đi qua server Apple, có thể bị log. Encrypt sensitive content, dùng Service Extension decrypt.

**Sound file không tìm thấy**: Custom sound phải bundle vào main app bundle, đặt tên đúng, format `.caf`/`.aiff`/`.wav`. File trong Asset Catalog không work.

**Notification không clear khi tap**: Phải gọi `UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:)` hoặc `removeAllDeliveredNotifications()` để clean Notification Center.

## 17. Testing strategy

**Local development**:
- Push payload từ Terminal qua `curl` tới sandbox endpoint.
- Hoặc dùng tool: **APNs Pusher**, **Knuff**, **Houston** (Ruby), **node-apn**.

**Simulator** (Xcode 11.4+):
```bash
xcrun simctl push <device-id> <bundle-id> payload.json
```
Hỗ trợ cả notification thường và Live Activity (Xcode 15+). Nhưng silent push behaviour trên Simulator KHÔNG giống device thật → vẫn phải test trên thiết bị.

**Production debugging**: dùng **CloudKit Dashboard** (nếu dùng CloudKit Subscriptions), Firebase Console (FCM), hoặc xem APNs response code + apns-id trong log server.

## 18. Architecture đề xuất cho app lớn

Tầng tách rời:

```
┌──────────────────────────────────────────┐
│ NotificationPermissionManager            │ ← Request quyền, track state
├──────────────────────────────────────────┤
│ DeviceTokenManager                       │ ← Cache token, gửi backend, retry
├──────────────────────────────────────────┤
│ NotificationCoordinator                  │ ← Parse userInfo, route deep link
│  - pendingNotification queue             │
│  - replay khi appReady                   │
├──────────────────────────────────────────┤
│ NotificationCategoryRegistrar            │ ← Define & register categories
├──────────────────────────────────────────┤
│ NotificationActionHandler                │ ← Handle reply, like, dismiss...
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────┐
│ Service Extension (separate target)      │
│  - DecryptionService (Keychain shared)   │
│  - AttachmentDownloader                  │
└──────────────────────────────────────────┘
```

Tách concerns rõ ràng → unit test được từng phần. `NotificationCoordinator` follow đúng pattern queue + replay như `DeepLinkCoordinator` đã thảo luận.

## 19. Tổng kết — Mental model

Push notification trong iOS không chỉ là "gửi message tới user". Nó là một **distributed system** với 3 actors, có constraints về size, delivery guarantee, battery, privacy. Senior cần nắm:

- **APNs là bottleneck duy nhất** — mọi notification phải qua Apple, không có cách nào khác.
- **Token mutable** — không cache forever, luôn re-register, server tự clean up.
- **Delivery không guaranteed** — đặc biệt silent push. Mission-critical phải có fallback.
- **Privacy by design** — payload qua server Apple, encrypt anything sensitive.
- **Extensions là cứu cánh** — cho rich content, decryption, custom UI; thiết kế share state qua App Group + shared Keychain.
- **Lifecycle phức tạp** — foreground/background/killed handling đều khác nhau, cold start cần queue + replay pattern.

Khi design notification feature mới, nên start từ câu hỏi: notification này **time-sensitive** không, **silent hay visible**, có cần **interactive action** không, payload có **sensitive data** không. Trả lời 4 câu này → quyết định được type, priority, interruption-level, có cần Extension hay không.
