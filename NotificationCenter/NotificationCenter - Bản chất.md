# `NotificationCenter` — Hướng dẫn chi tiết cho senior iOS

## 1. Bản chất

`NotificationCenter` là implementation của **Observer pattern** (publish-subscribe) ở mức process. Nó cho phép các object giao tiếp với nhau mà không cần biết về sự tồn tại của nhau — decoupling hoàn toàn giữa publisher và subscriber.

Một số điểm cần nhớ:

- `NotificationCenter.default` là singleton cho mỗi process — notifications **không** vượt qua biên giới process. Trên macOS có `DistributedNotificationCenter` cho cross-process, iOS thì không.
- Việc post là **synchronous**: khi gọi `post()`, control flow sẽ block cho đến khi tất cả observer xử lý xong (trừ khi observer dùng queue khác).
- `Notification` là một `struct` gồm 3 phần: `name: Notification.Name`, `object: Any?` (sender), và `userInfo: [AnyHashable: Any]?` (payload).

## 2. Định nghĩa `Notification.Name`

Luôn dùng extension để tránh "stringly-typed":

```swift
extension Notification.Name {
    static let userDidLogin = Notification.Name("com.myapp.userDidLogin")
    static let cartDidUpdate = Notification.Name("com.myapp.cartDidUpdate")
}
```

Convention: dùng reverse-DNS prefix để tránh collision với SDK của bên thứ ba.

## 3. Posting notification

Có 3 overload chính:

```swift
// Cách 1: chỉ tên
NotificationCenter.default.post(name: .userDidLogin, object: nil)

// Cách 2: kèm sender
NotificationCenter.default.post(name: .userDidLogin, object: self)

// Cách 3: kèm payload
NotificationCenter.default.post(
    name: .userDidLogin,
    object: self,
    userInfo: ["userId": "abc123", "timestamp": Date()]
)
```

Tham số `object` rất hữu ích: nếu observer đăng ký với một `object` cụ thể, nó chỉ nhận notification từ sender đó. Đây là cách để filter mà nhiều developer bỏ qua.

## 4. Bốn cách observe — từ legacy đến modern

### 4.1. Selector-based (Objective-C style)

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleLogin(_:)),
    name: .userDidLogin,
    object: nil
)

@objc private func handleLogin(_ notification: Notification) {
    guard let userId = notification.userInfo?["userId"] as? String else { return }
    // ...
}
```

- Method bắt buộc phải `@objc`.
- Từ iOS 9 trở đi, framework tự động remove observer khi `self` bị deallocate cho biến thể này. Tuy nhiên tớ vẫn khuyến nghị remove tường minh trong `deinit` để rõ ý.
- Không có closure capture → không lo retain cycle nhưng cũng kém linh hoạt.

### 4.2. Block-based

```swift
private var loginToken: NSObjectProtocol?

loginToken = NotificationCenter.default.addObserver(
    forName: .userDidLogin,
    object: nil,
    queue: .main
) { [weak self] notification in
    self?.handleLogin(notification)
}
```

Đây là cách phổ biến nhất hiện nay, nhưng có **3 cái bẫy**:

1. **Phải retain token**: nếu không giữ token, observer vẫn hoạt động nhưng bạn không có cách nào remove nó.
2. **Phải remove tường minh**: khác với selector-based, biến thể này **không** auto-remove. Quên remove → leak + crash tiềm ẩn.
3. **Retain cycle**: nếu capture `self` mạnh trong closure, `self` sẽ giữ token, token giữ closure, closure giữ `self`. Luôn `[weak self]`.

```swift
deinit {
    if let token = loginToken {
        NotificationCenter.default.removeObserver(token)
    }
}
```

Tham số `queue` quyết định `OperationQueue` mà block chạy trên đó:
- `.main` — chạy trên main thread (tốt cho UI updates).
- `nil` — chạy đồng bộ trên thread của poster (mặc định).
- Custom queue — control thêm.

### 4.3. Combine Publisher

```swift
import Combine

private var cancellables = Set<AnyCancellable>()

NotificationCenter.default
    .publisher(for: .userDidLogin)
    .compactMap { $0.userInfo?["userId"] as? String }
    .receive(on: DispatchQueue.main)
    .sink { [weak self] userId in
        self?.refreshProfile(for: userId)
    }
    .store(in: &cancellables)
```

Ưu điểm: chain được với các operator của Combine (debounce, filter, merge…), tự động cleanup khi `cancellables` bị deallocate. Đây là cách yêu thích của tớ khi đã dùng Combine trong codebase.

### 4.4. Async/await — `AsyncSequence` (iOS 15+)

```swift
Task {
    for await notification in NotificationCenter.default.notifications(named: .userDidLogin) {
        guard let userId = notification.userInfo?["userId"] as? String else { continue }
        await refreshProfile(for: userId)
    }
}
```

Đây là cách modern nhất, tích hợp tự nhiên với structured concurrency. Lưu ý quan trọng:

- `notifications(named:object:)` bị **`@MainActor`-isolated** từ Swift 5.10/iOS 17 vì lý do Sendable. Trước đó có thể gọi từ bất kỳ context nào.
- Khi `Task` bị cancel, vòng `for await` tự thoát → không cần `removeObserver` thủ công. Đây là điểm mạnh lớn nhất.
- Nếu observer chạy lâu, các notification mới có thể bị drop (back-pressure semantics của AsyncSequence).

## 5. Pattern type-safe cho `userInfo` (senior pattern)

`userInfo: [AnyHashable: Any]?` là điểm yếu lớn nhất của NotificationCenter — không có compile-time safety. Một pattern hay dùng để wrap lại:

```swift
struct UserLoginPayload {
    let userId: String
    let timestamp: Date
}

protocol TypedNotification {
    associatedtype Payload
    static var name: Notification.Name { get }
}

extension TypedNotification {
    static func post(_ payload: Payload, on center: NotificationCenter = .default) {
        center.post(name: name, object: nil, userInfo: ["payload": payload])
    }

    static func observe(
        on center: NotificationCenter = .default,
        queue: OperationQueue = .main,
        handler: @escaping (Payload) -> Void
    ) -> NSObjectProtocol {
        center.addObserver(forName: name, object: nil, queue: queue) { notification in
            guard let payload = notification.userInfo?["payload"] as? Payload else { return }
            handler(payload)
        }
    }
}

enum UserLoginNotification: TypedNotification {
    typealias Payload = UserLoginPayload
    static let name = Notification.Name("com.myapp.userDidLogin")
}

// Sử dụng:
UserLoginNotification.post(UserLoginPayload(userId: "abc", timestamp: .now))

let token = UserLoginNotification.observe { payload in
    print(payload.userId) // type-safe!
}
```

## 6. System notifications quan trọng

Một số notification của hệ thống senior nào cũng phải biết:

| Notification | Khi nào |
|---|---|
| `UIApplication.didBecomeActiveNotification` | App vào foreground và active |
| `UIApplication.willResignActiveNotification` | App sắp mất active state |
| `UIApplication.didEnterBackgroundNotification` | App vào background |
| `UIApplication.didReceiveMemoryWarningNotification` | Memory warning |
| `UIResponder.keyboardWillShowNotification` | Bàn phím sắp hiện |
| `UIResponder.keyboardWillHideNotification` | Bàn phím sắp ẩn |
| `NSManagedObjectContext.didSaveObjectsNotification` | Core Data save |

Đặc biệt với keyboard, frame và animation duration nằm trong `userInfo`:

```swift
NotificationCenter.default.addObserver(
    forName: UIResponder.keyboardWillShowNotification,
    object: nil,
    queue: .main
) { notification in
    guard
        let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
    else { return }
    // adjust UI
}
```

## 7. Threading concerns

`post()` chạy synchronous trên thread của caller. Nghĩa là:

- Nếu post từ background thread, tất cả observer (với `queue: nil`) sẽ chạy trên background thread đó.
- Nếu observer cần update UI, **bắt buộc** phải dùng `queue: .main` hoặc `DispatchQueue.main.async` bên trong.
- Nhiều system notification (như `NSManagedObjectContextDidSave`) post trên thread không phải main → cẩn thận khi observe.

## 8. Memory management — checklist cho senior

- ✅ Block-based: luôn lưu token, remove trong `deinit`.
- ✅ Closure: luôn `[weak self]`.
- ✅ Combine: `store(in: &cancellables)` — cleanup tự động khi owner deallocate.
- ✅ AsyncSequence: cancel `Task` để dừng observe.
- ✅ Selector-based: iOS 9+ auto-cleanup nhưng vẫn nên explicit để code rõ ý.

## 9. Testability

Đừng dùng `.default` trực tiếp trong class cần test — inject `NotificationCenter`:

```swift
final class AnalyticsTracker {
    private let center: NotificationCenter
    
    init(center: NotificationCenter = .default) {
        self.center = center
    }
}

// Test:
let mockCenter = NotificationCenter()
let tracker = AnalyticsTracker(center: mockCenter)
mockCenter.post(name: .userDidLogin, object: nil)
// assert behavior
```

## 10. Khi nào dùng / không dùng

**Nên dùng khi:**
- Broadcast 1-to-many (vd: theme changed, user logged out).
- Cross-cutting concern không thuộc về một module cụ thể.
- Observe system events (keyboard, app lifecycle).
- Decouple các module không nên biết về nhau.

**Không nên dùng khi:**
- Giao tiếp 1-1 → dùng **delegate** hoặc **closure**.
- Stream giá trị reactive → dùng **Combine** hoặc **AsyncSequence** trực tiếp.
- State trong View-Model → `@Observable` / `@Published` / SwiftUI binding.
- Lúc cần observe key path của object → **KVO**.

## 11. Pitfalls thường gặp

1. **Notification storm**: post quá nhiều trong vòng lặp → throttle hoặc debounce với Combine.
2. **Order of observers không xác định**: đừng dependency vào thứ tự nhận notification.
3. **Reentrant post**: observer A nhận notification rồi post tiếp notification khác → dễ thành recursion vô hạn.
4. **userInfo không type-safe** → dùng pattern ở phần 5.
5. **Hard to debug**: khi có nhiều observer, khó trace flow → cân nhắc dùng Combine hoặc explicit event bus.

---

Nếu cần đi sâu thêm vào phần nào — ví dụ implement event bus type-safe trên top của NotificationCenter, hoặc bridge từ NotificationCenter sang `@Observable` của iOS 17 — tớ có thể tiếp tục.
