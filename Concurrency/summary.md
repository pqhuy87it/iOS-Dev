# Modern Swift Concurrency trong SwiftUI

Chào Huy! Đây là một chủ đề rất quan trọng cho production SwiftUI apps. Mình sẽ đi qua từng khía cạnh chi tiết.

---

## 1. `.task` Modifier — Thay thế `onAppear` cho async work

`.task` là cách chính để trigger async work khi View xuất hiện. Nó có 2 ưu điểm lớn so với `onAppear`:
- **Tự động cancel** khi View bị remove khỏi hierarchy
- **Hỗ trợ `await`** trực tiếp bên trong

```swift
struct UserProfileView: View {
    @State private var user: User?
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let user {
                Text(user.name)
            } else if let error {
                Text("Error: \(error.localizedDescription)")
            } else {
                ProgressView()
            }
        }
        .task {
            // Tự động chạy trên MainActor context vì SwiftUI View body là @MainActor
            do {
                user = try await UserService.shared.fetchProfile()
            } catch {
                // Task bị cancel sẽ throw CancellationError
                if !(error is CancellationError) {
                    self.error = error
                }
            }
        }
    }
}
```

### `.task(id:)` — Re-trigger khi value thay đổi

Đây là pattern cực kỳ mạnh cho **reactive data fetching**:

```swift
struct SearchView: View {
    @State private var query = ""
    @State private var results: [Item] = []
    
    var body: some View {
        List(results) { item in
            Text(item.title)
        }
        .searchable(text: $query)
        .task(id: query) {
            // Mỗi khi query thay đổi:
            // 1. Task cũ bị CANCEL tự động
            // 2. Task mới được tạo
            
            // Debounce tự nhiên bằng cách delay
            do {
                try await Task.sleep(for: .milliseconds(300))
                results = try await SearchService.search(query)
            } catch {
                // CancellationError xảy ra khi user gõ tiếp → task cũ bị cancel
                // Không cần xử lý gì
            }
        }
    }
}
```

**Senior mindset:** `.task(id:)` thực chất cho bạn **debounce + cancellation miễn phí**. Đây là pattern thay thế hoàn toàn Combine `debounce` + `switchToLatest` mà code đơn giản hơn rất nhiều.

---

## 2. `@MainActor` và Thread Safety

### SwiftUI View đã là `@MainActor`

Từ Swift 5.5+, toàn bộ SwiftUI View body chạy trên `@MainActor`. Điều này có nghĩa mọi `@State` mutation trong `.task` đều an toàn:

```swift
.task {
    let data = try await api.fetch() // Chạy trên background (nếu fetch không @MainActor)
    self.items = data                // Tự động hop về MainActor vì @State
}
```

### ViewModel với `@MainActor`

```swift
@MainActor
@Observable
class ProfileViewModel {
    var user: User?
    var isLoading = false
    var errorMessage: String?
    
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol = UserService.shared) {
        self.userService = userService
    }
    
    func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            user = try await userService.fetchProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    
    var body: some View {
        content
            .task { await viewModel.loadProfile() }
    }
}
```

**Lưu ý quan trọng:** Khi đánh `@MainActor` lên toàn bộ class, mọi property và method đều chạy trên main thread. Nếu có heavy computation, bạn cần **explicitly** đẩy sang background:

```swift
@MainActor
@Observable
class ImageProcessorViewModel {
    var processedImage: UIImage?
    
    func processImage(_ input: UIImage) async {
        // Đẩy heavy work ra khỏi MainActor
        let result = await Task.detached(priority: .userInitiated) {
            return HeavyImageProcessor.apply(filters: input)
        }.value
        
        // Tự động về MainActor vì class là @MainActor
        processedImage = result
    }
}
```

---

## 3. `AsyncSequence` trong SwiftUI — Streaming Data

### Dùng `for await` trong `.task`

```swift
struct NotificationsView: View {
    @State private var notifications: [Notification] = []
    
    var body: some View {
        List(notifications) { notification in
            NotificationRow(notification)
        }
        .task {
            // Stream liên tục cho đến khi View bị remove → task cancel → stream dừng
            do {
                for await notification in NotificationService.shared.stream() {
                    notifications.append(notification)
                }
            } catch {
                print("Stream ended: \(error)")
            }
        }
    }
}
```

### `AsyncStream` — Bridge từ callback/delegate sang async

```swift
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocation>.Continuation?
    
    var locations: AsyncStream<CLLocation> {
        AsyncStream { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.startUpdatingLocation()
            
            // Cleanup khi stream bị cancel (View disappear)
            continuation.onTermination = { @Sendable _ in
                // Chú ý: cần dispatch vì onTermination có thể chạy trên bất kỳ thread
                Task { @MainActor in
                    self.manager.stopUpdatingLocation()
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locations.forEach { continuation?.yield($0) }
    }
}

// Sử dụng trong SwiftUI
struct MapView: View {
    @State private var currentLocation: CLLocation?
    private let locationManager = LocationManager()
    
    var body: some View {
        Map(/* ... */)
            .task {
                for await location in locationManager.locations {
                    currentLocation = location
                }
            }
    }
}
```

---

## 4. `TaskGroup` — Parallel Loading

Khi cần fetch nhiều data sources đồng thời:

```swift
struct DashboardView: View {
    @State private var dashboard: DashboardData?
    
    var body: some View {
        DashboardContent(data: dashboard)
            .task {
                dashboard = await loadDashboard()
            }
    }
    
    private func loadDashboard() async -> DashboardData {
        async let profile = UserService.fetchProfile()
        async let stats = StatsService.fetchStats()
        async let notifications = NotificationService.fetchRecent()
        
        // 3 requests chạy song song, await tất cả
        return await DashboardData(
            profile: try? profile,
            stats: try? stats,
            notifications: (try? notifications) ?? []
        )
    }
}
```

Với **dynamic number of tasks**, dùng `TaskGroup`:

```swift
func loadAllImages(urls: [URL]) async -> [URL: UIImage] {
    await withTaskGroup(of: (URL, UIImage?).self) { group in
        for url in urls {
            group.addTask {
                let image = try? await ImageLoader.load(url)
                return (url, image)
            }
        }
        
        var results: [URL: UIImage] = [:]
        for await (url, image) in group {
            if let image {
                results[url] = image
            }
        }
        return results
    }
}
```

**Senior mindset:** `async let` dùng khi bạn biết **compile-time** có bao nhiêu tasks. `TaskGroup` dùng khi số lượng tasks là **dynamic/runtime**.

---

## 5. Actor — Data Isolation cho Shared Mutable State

```swift
actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [URL: UIImage] = [:]
    private var inProgress: [URL: Task<UIImage, Error>] = [:]
    
    func image(for url: URL) async throws -> UIImage {
        // Check cache
        if let cached = cache[url] {
            return cached
        }
        
        // Coalesce duplicate requests (quan trọng cho performance!)
        if let existing = inProgress[url] {
            return try await existing.value
        }
        
        // Tạo task mới
        let task = Task {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                throw ImageError.invalidData
            }
            return image
        }
        
        inProgress[url] = task
        
        do {
            let image = try await task.value
            cache[url] = image
            inProgress[url] = nil
            return image
        } catch {
            inProgress[url] = nil
            throw error
        }
    }
}
```

Sử dụng trong SwiftUI:

```swift
struct AsyncCachedImage: View {
    let url: URL
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            image = try? await ImageCache.shared.image(for: url)
        }
    }
}
```

---

## 6. `withCheckedContinuation` / `withCheckedThrowingContinuation`

Bridge API cũ (callback-based) sang async/await:

```swift
extension PHPhotoLibrary {
    static func requestAuthorizationAsync(for level: PHAccessLevel) async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            requestAuthorization(for: level) { status in
                continuation.resume(returning: status)
            }
        }
    }
}

// Dùng trong SwiftUI
struct PhotoPickerView: View {
    @State private var authStatus: PHAuthorizationStatus?
    
    var body: some View {
        content
            .task {
                authStatus = await PHPhotoLibrary.requestAuthorizationAsync(for: .readWrite)
            }
    }
}
```

**⚠️ Lưu ý critical:** `continuation.resume` chỉ được gọi **đúng 1 lần**. Gọi 0 lần → memory leak / hang. Gọi 2 lần → crash.

---

## 7. Cancellation Handling — Production Pattern

```swift
struct PaginatedListView: View {
    @State private var items: [Item] = []
    @State private var page = 1
    
    var body: some View {
        List {
            ForEach(items) { item in
                ItemRow(item)
            }
            
            // Infinite scroll trigger
            ProgressView()
                .task(id: page) {
                    await loadPage(page)
                }
        }
    }
    
    private func loadPage(_ page: Int) async {
        do {
            // Kiểm tra cancellation trước network call
            try Task.checkCancellation()
            
            let newItems = try await ItemService.fetch(page: page)
            
            // Kiểm tra lần nữa sau khi await trở về
            try Task.checkCancellation()
            
            items.append(contentsOf: newItems)
        } catch is CancellationError {
            // View đã disappear, không làm gì
        } catch {
            // Handle real errors
        }
    }
}
```

---

## 8. `@Observable` + Swift Concurrency (iOS 17+)

Pattern hiện đại nhất, kết hợp `@Observable` macro với structured concurrency:

```swift
@MainActor
@Observable
class ChatViewModel {
    var messages: [Message] = []
    var inputText = ""
    var isSending = false
    
    private let chatService: ChatService
    private var streamTask: Task<Void, Never>?
    
    init(chatService: ChatService) {
        self.chatService = chatService
    }
    
    func startListening() async {
        // Structured: task tự cancel khi .task modifier cleanup
        for await message in chatService.messageStream {
            messages.append(message)
        }
    }
    
    func send() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        isSending = true
        
        // Unstructured task — cần quản lý lifecycle thủ công
        streamTask = Task {
            defer { isSending = false }
            do {
                try await chatService.send(text)
            } catch {
                inputText = text // Restore on failure
            }
        }
    }
    
    func cancelSend() {
        streamTask?.cancel()
    }
    
    deinit {
        streamTask?.cancel()
    }
}
```

---

## So sánh tổng quan các pattern

| Pattern | Use Case | Lifecycle | Thread |
|---|---|---|---|
| `.task { }` | One-shot async khi view appear | Tự cancel khi view disappear | Inherit MainActor từ View |
| `.task(id:)` | Reactive re-fetch khi data thay đổi | Cancel task cũ + tạo mới | Inherit MainActor |
| `async let` | Parallel fetch (biết trước số lượng) | Structured, cancel implicit | Caller's actor |
| `TaskGroup` | Parallel fetch (dynamic) | Structured, cancel tất cả khi group exit | Caller's actor |
| `Task { }` | Fire-and-forget từ sync context | **Unstructured** — phải tự cancel | Inherit actor context |
| `Task.detached` | Heavy work cần tách khỏi MainActor | **Unstructured** — phải tự cancel | Không inherit actor |
| `Actor` | Shared mutable state isolation | Lifetime của actor instance | Actor's serial executor |

---

## Anti-patterns cần tránh

**1. Dùng `Task { }` trong `onAppear` thay vì `.task`:**
```swift
// ❌ Không tự cancel → memory leak, race condition
.onAppear {
    Task { await viewModel.load() }
}

// ✅ Structured, tự cancel
.task { await viewModel.load() }
```

**2. Blocking MainActor bằng heavy computation:**
```swift
// ❌ UI freeze
.task {
    let result = heavyComputation(data) // sync, chạy trên MainActor
    self.result = result
}

// ✅ Offload sang background
.task {
    let result = await Task.detached {
        heavyComputation(data)
    }.value
    self.result = result
}
```

**3. Quên handle `CancellationError`:**
```swift
// ❌ Log lỗi giả khi user navigate away
.task {
    do {
        data = try await fetch()
    } catch {
        logger.error("Failed: \(error)") // CancellationError cũng bị log
    }
}

// ✅ Filter cancellation
.task {
    do {
        data = try await fetch()
    } catch is CancellationError {
        // Expected, do nothing
    } catch {
        logger.error("Failed: \(error)")
    }
}
```

Nếu cần mình đi sâu thêm vào bất kỳ pattern nào (ví dụ `AsyncSequence` nâng cao, `TaskLocal`, hay `Sendable` conformance), cứ nói nhé!
