# `NotificationCenter` trong SwiftUI — Hướng dẫn chi tiết

SwiftUI được xây dựng trên triết lý declarative + reactive, nên cách tiếp cận `NotificationCenter` khác hẳn UIKit. Thay vì `addObserver`/`removeObserver` thủ công, SwiftUI cung cấp các cơ chế tự động gắn với **view lifecycle** — đăng ký khi view xuất hiện, hủy khi view biến mất, không cần `deinit`.

## 1. `.onReceive(_:)` — Cách SwiftUI-native nhất

Đây là modifier được thiết kế riêng để observe Combine publisher, và `NotificationCenter` có sẵn API `publisher(for:)`:

```swift
struct ContentView: View {
    @State private var isActive = true

    var body: some View {
        Text(isActive ? "Active" : "Inactive")
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                isActive = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                isActive = false
            }
    }
}
```

Đặc điểm cần nhớ:

- Subscription được tạo khi view xuất hiện và **tự động cancel** khi view bị remove khỏi hierarchy → không leak.
- Closure chạy trên **main thread** vì SwiftUI body luôn ở MainActor. Tớ vẫn khuyến nghị explicit `.receive(on: DispatchQueue.main)` nếu publisher có thể emit từ background.
- Có thể chain nhiều `.onReceive` trên cùng một view — mỗi cái là một subscription độc lập.

### Transform trước khi nhận

`.onReceive` nhận bất kỳ Publisher nào, nên có thể chain operator Combine trước:

```swift
.onReceive(
    NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }
        .removeDuplicates()
) { height in
    keyboardHeight = height
}
```

## 2. `.task` + `AsyncSequence` — Cách modern (iOS 15+)

Nếu codebase đã chuyển sang structured concurrency, đây là cách sạch nhất:

```swift
struct OrderListView: View {
    @State private var orders: [Order] = []

    var body: some View {
        List(orders) { order in
            OrderRow(order: order)
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .orderDidUpdate) {
                await refreshOrders()
            }
        }
    }
}
```

Điểm mạnh:

- `Task` do `.task` tạo ra **tự động cancel** khi view disappear → vòng `for await` thoát → cleanup tự động.
- Không cần quản lý token hay `cancellables`.
- Body của loop tự nhiên là async → gọi async function thoải mái.

Lưu ý quan trọng: từ Swift 5.10/iOS 17, `notifications(named:)` bị **`@MainActor`-isolated** vì lý do `Sendable`. Trong SwiftUI, vì `.task` chạy trong MainActor context theo mặc định nên không vướng — nhưng nếu cần observe từ một `Task.detached`, phải xử lý cẩn thận hơn.

## 3. Custom binding với `@Observable` (iOS 17+)

Khi notification cần share state giữa nhiều view, đóng gói trong observable model là pattern senior chuẩn:

```swift
@Observable
final class KeyboardMonitor {
    var height: CGFloat = 0
    var isVisible: Bool { height > 0 }
    
    private var showToken: NSObjectProtocol?
    private var hideToken: NSObjectProtocol?

    init() {
        showToken = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            self?.height = frame?.height ?? 0
        }

        hideToken = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.height = 0
        }
    }

    deinit {
        [showToken, hideToken].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }
}

struct ChatView: View {
    @State private var keyboard = KeyboardMonitor()

    var body: some View {
        VStack {
            MessageList()
            ComposerView()
                .padding(.bottom, keyboard.height)
                .animation(.easeOut, value: keyboard.height)
        }
    }
}
```

Pattern tương tự với `ObservableObject` cho codebase iOS 16-:

```swift
final class KeyboardMonitor: ObservableObject {
    @Published var height: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { ($0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height }

        let willHide = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }

        willShow.merge(with: willHide)
            .receive(on: DispatchQueue.main)
            .assign(to: &$height)
    }
}
```

## 4. `ScenePhase` — Thay thế cho app lifecycle notifications

Trong SwiftUI, app lifecycle nên ưu tiên `ScenePhase` thay vì các `UIApplication.*Notification`:

```swift
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MainContent()
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:     resumeWork()
                case .inactive:   pauseWork()
                case .background: persistState()
                @unknown default: break
                }
            }
    }
}
```

`ScenePhase` là SwiftUI-native, không phụ thuộc UIKit (chạy trên macOS, watchOS, tvOS), và đã handle multi-scene trên iPad đúng cách. Chỉ fallback về `NotificationCenter` khi cần thêm thông tin mà `ScenePhase` không cung cấp.

## 5. Cross-view communication

NotificationCenter rất hợp khi cần broadcast giữa các view không có quan hệ parent-child:

```swift
extension Notification.Name {
    static let didTapDeepLink = Notification.Name("didTapDeepLink")
}

struct AnyDeepLinkSourceView: View {
    var body: some View {
        Button("Open Profile") {
            NotificationCenter.default.post(
                name: .didTapDeepLink,
                object: nil,
                userInfo: ["route": "profile/123"]
            )
        }
    }
}

struct RootView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    DestinationView(route: route)
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapDeepLink)) { note in
            guard let routeString = note.userInfo?["route"] as? String,
                  let route = Route(rawValue: routeString) else { return }
            path.append(route)
        }
    }
}
```

Đây là một trong những use case mạnh nhất: tránh phải truyền closure qua hàng loạt view xuống nested level sâu.

## 6. Bridge `NotificationCenter` → state với operator

Một pattern tớ hay dùng để biến notification thành state binding sạch:

```swift
extension View {
    func onNotification(
        _ name: Notification.Name,
        perform action: @escaping (Notification) -> Void
    ) -> some View {
        onReceive(NotificationCenter.default.publisher(for: name), perform: action)
    }
}

// Sử dụng:
ContentView()
    .onNotification(.userDidLogout) { _ in
        navigationPath = NavigationPath()
    }
```

Với typed-notification pattern đã đề cập ở phần trước, có thể đẩy lên thêm một tầng:

```swift
extension View {
    func onTypedNotification<N: TypedNotification>(
        _ type: N.Type,
        perform action: @escaping (N.Payload) -> Void
    ) -> some View {
        onReceive(NotificationCenter.default.publisher(for: N.name)) { notification in
            if let payload = notification.userInfo?["payload"] as? N.Payload {
                action(payload)
            }
        }
    }
}

// Type-safe sử dụng:
.onTypedNotification(UserLoginNotification.self) { payload in
    print(payload.userId) // compile-time checked
}
```

## 7. Bridge `Notification` → `Binding`

Khi muốn một notification cập nhật một `Binding` (vd: từ legacy code post notification, SwiftUI view nhận):

```swift
@State private var refreshTrigger = 0

var body: some View {
    DataView(version: refreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .dataDidChange)) { _ in
            refreshTrigger &+= 1
        }
}
```

Pattern này dùng `&+=` (overflow-safe) để bump state, force re-render mà không lo overflow sau nhiều giờ.

## 8. Pitfalls đặc thù SwiftUI

### 8.1. View được tạo lại nhiều lần

Body của SwiftUI view được gọi nhiều lần, nhưng `.onReceive` được attach vào view identity, không phải mỗi lần body chạy. Tuy nhiên, nếu publisher được **tạo lại** ở mỗi lần body chạy, SwiftUI sẽ unsubscribe/resubscribe → có thể miss events trong khoảng thời gian ngắn:

```swift
// ⚠️ Bad: publisher tạo lại mỗi render
.onReceive(makeFilteredPublisher()) { ... }

// ✅ Good: publisher ổn định
.onReceive(NotificationCenter.default.publisher(for: .myEvent)) { ... }
```

Nếu cần publisher phức tạp, lưu trong observable model.

### 8.2. `@StateObject` vs `@State` cho observable model

Với class lưu token NotificationCenter:

- **`@StateObject`** (ObservableObject) hoặc **`@State`** (cho `@Observable`): SwiftUI giữ instance qua các lần re-render → token không bị tạo lại nhiều lần.
- **`@ObservedObject`** hoặc khởi tạo trong body trực tiếp: instance bị tạo lại liên tục → token leak hoặc miss events.

```swift
// ❌ Sai
struct MyView: View {
    let monitor = KeyboardMonitor() // tạo lại mỗi lần parent re-render!
}

// ✅ Đúng (iOS 17+)
struct MyView: View {
    @State private var monitor = KeyboardMonitor()
}
```

### 8.3. Nhận notification khi view ẩn

`.onReceive` chỉ chạy khi view trong hierarchy. Nếu view đang ở dưới một sheet hoặc trong tab khác, hành vi phụ thuộc cách SwiftUI giữ view:

- `TabView` mặc định **giữ** view của các tab khác → `.onReceive` vẫn fire.
- `NavigationStack` pop view → view biến mất → unsubscribe.

Đây là nguồn gốc của bug "tại sao notification không nhận được sau khi back về" — vì khi view trở lại, nó được tạo mới và có thể đã miss notification.

Giải pháp: lưu state ở observable model **bên ngoài view** (ví dụ `@Environment` hoặc shared `@Observable`), để model luôn listen độc lập với view lifecycle.

### 8.4. Closure trong `.onReceive` không có `self`

`.onReceive` closure không capture View struct vì View là value type → không lo retain cycle như UIKit. Nhưng nếu closure capture observable model, cẩn thận với việc trigger update gây vòng lặp.

## 9. Khi nào dùng cái nào — Decision tree

| Tình huống | Cách dùng |
|---|---|
| App lifecycle (active/inactive/background) | `@Environment(\.scenePhase)` |
| Keyboard, system events | `.onReceive` hoặc observable `KeyboardMonitor` |
| Cross-view broadcast (deep link, logout) | `.onReceive` ở root view |
| State cần share qua nhiều view | `@Observable` model bridging từ NotificationCenter |
| One-shot async observation | `.task` + `AsyncSequence` |
| Codebase Combine-heavy | `.publisher(for:)` + operators |
| Legacy UIKit notification trong SwiftUI | `.onReceive(publisher(for:))` |

## 10. Test trong SwiftUI

Inject NotificationCenter vào model qua initializer rồi inject model qua `@Environment` để test:

```swift
@Observable
final class AppEvents {
    private let center: NotificationCenter
    var lastEvent: String?

    init(center: NotificationCenter = .default) {
        self.center = center
        // observe...
    }
}

// Test
let testCenter = NotificationCenter()
let events = AppEvents(center: testCenter)
testCenter.post(name: .userDidLogin, object: nil, userInfo: ["userId": "test"])
// assert events.lastEvent
```

---

Nếu muốn, tớ có thể đi sâu thêm vào: implement type-safe event bus dùng `@Observable` làm "central store" thay cho `NotificationCenter`, hoặc cách wrap `AsyncSequence` notification vào custom `ViewModifier` để tái sử dụng.
