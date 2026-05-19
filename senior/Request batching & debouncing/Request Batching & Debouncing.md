# Request Batching & Debouncing trong iOS

## 1. Debouncing

### Vấn đề

Khi user gõ vào search bar, mỗi keystroke trigger một API call. Gõ "iPhone" = 6 request liên tiếp: "i", "iP", "iPh", "iPho", "iPhon", "iPhone". Phần lớn response trả về đều bị discard ngay lập tức vì user vẫn đang gõ tiếp.

### Cơ chế hoạt động

Debounce nghĩa là: **chờ một khoảng thời gian im lặng** trước khi thực sự thực thi. Mỗi lần có input mới, timer reset về 0.

### Implementation với Combine

```swift
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [Item] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        $query
            // Chờ 300ms sau keystroke cuối
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            // Bỏ qua nếu text không đổi (ví dụ user gõ rồi xóa lại)
            .removeDuplicates()
            // Bỏ query rỗng
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // Cancel request cũ nếu có query mới
            .map { [unowned self] query in
                self.searchAPI(query: query)
                    .catch { _ in Just([]) }
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .assign(to: &$results)
    }
    
    private func searchAPI(query: String) -> AnyPublisher<[Item], Error> {
        let url = URL(string: "https://api.example.com/search?q=\(query)")!
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Item].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
```

### Tại sao `switchToLatest` quan trọng?

Giả sử user gõ "ip" → pause 300ms → request A bay đi → user gõ tiếp "iphone" → pause 300ms → request B bay đi. Nếu request A trả về **sau** request B (do network không đảm bảo thứ tự), UI sẽ hiển thị kết quả sai. `switchToLatest` tự động cancel request A khi request B bắt đầu, tránh race condition.

### Implementation với async/await (iOS 15+)

```swift
actor SearchDebouncer {
    private var currentTask: Task<Void, Never>?
    
    func debounce(
        interval: Duration = .milliseconds(300),
        operation: @escaping @Sendable () async throws -> Void
    ) {
        currentTask?.cancel()
        currentTask = Task {
            do {
                try await Task.sleep(for: interval)
                // Nếu chưa bị cancel sau khi sleep → thực thi
                guard !Task.isCancelled else { return }
                try await operation()
            } catch is CancellationError {
                // Bị cancel bởi keystroke mới → bình thường
            } catch {
                // Handle error
            }
        }
    }
}
```

Cách dùng:

```swift
@Observable
class SearchViewModel {
    var query: String = "" {
        didSet { onQueryChanged() }
    }
    var results: [Item] = []
    
    private let debouncer = SearchDebouncer()
    
    private func onQueryChanged() {
        debouncer.debounce { [weak self] in
            guard let self, !query.isEmpty else { return }
            let items = try await APIClient.search(query: query)
            await MainActor.run { self.results = items }
        }
    }
}
```

---

## 2. Request Batching

### Vấn đề

Một màn hình hiển thị 20 cell, mỗi cell cần fetch avatar riêng. Nếu gọi 20 request riêng lẻ, ta lãng phí connection overhead, header lặp lại, và có thể bị server rate-limit.

### Cơ chế hoạt động

Thu thập các request trong một **time window** ngắn (ví dụ 50ms), sau đó gộp thành một batch request duy nhất.

### Implementation

```swift
actor RequestBatcher<Key: Hashable & Sendable, Value: Sendable> {
    
    private var pendingKeys: Set<Key> = []
    private var continuations: [Key: [CheckedContinuation<Value, Error>]] = [:]
    private var flushTask: Task<Void, Never>?
    
    private let batchFetcher: @Sendable ([Key]) async throws -> [Key: Value]
    private let windowDuration: Duration
    
    init(
        windowDuration: Duration = .milliseconds(50),
        batchFetcher: @escaping @Sendable ([Key]) async throws -> [Key: Value]
    ) {
        self.windowDuration = windowDuration
        self.batchFetcher = batchFetcher
    }
    
    /// Caller gọi hàm này cho từng key riêng lẻ,
    /// nhưng bên trong sẽ được gộp lại
    func fetch(key: Key) async throws -> Value {
        return try await withCheckedThrowingContinuation { continuation in
            pendingKeys.insert(key)
            continuations[key, default: []].append(continuation)
            scheduleFlush()
        }
    }
    
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task {
            try? await Task.sleep(for: windowDuration)
            await flush()
        }
    }
    
    private func flush() {
        let keys = pendingKeys
        let waiting = continuations
        pendingKeys.removeAll()
        continuations.removeAll()
        flushTask = nil
        
        Task {
            do {
                let results = try await batchFetcher(Array(keys))
                for (key, conts) in waiting {
                    if let value = results[key] {
                        conts.forEach { $0.resume(returning: value) }
                    } else {
                        let err = BatchError.missingKey(String(describing: key))
                        conts.forEach { $0.resume(throwing: err) }
                    }
                }
            } catch {
                waiting.values.flatMap { $0 }.forEach {
                    $0.resume(throwing: error)
                }
            }
        }
    }
}
```

Cách dùng:

```swift
// Setup: gộp nhiều user ID thành 1 request
let userBatcher = RequestBatcher<String, UserProfile>(
    windowDuration: .milliseconds(100)
) { userIDs in
    // POST /users/batch { "ids": ["u1", "u2", ...] }
    let profiles = try await APIClient.fetchUsers(ids: userIDs)
    return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
}

// Trong mỗi cell — code trông như gọi riêng lẻ,
// nhưng thực tế được gộp tự động
func configureCell(userID: String) async {
    let profile = try await userBatcher.fetch(key: userID)
    avatarView.load(url: profile.avatarURL)
}
```

20 cell gọi `fetch` gần như đồng thời → batcher gom lại → 1 request duy nhất.

---

## 3. So sánh & Khi nào dùng gì

| Tiêu chí | Debouncing | Batching |
|---|---|---|
| Mục đích | Giảm tần suất gọi từ **1 nguồn** | Gộp nhiều request từ **nhiều nguồn** |
| Trigger | User input liên tục | Nhiều component cùng cần data |
| Cơ chế | Delay + reset timer | Time window + gom request |
| Ví dụ | Search bar, auto-save, resize | Avatar loading, analytics, GraphQL |

## 4. Lưu ý thực tế cho Senior

**Chọn debounce interval hợp lý.** 300ms là con số phổ biến cho search. Quá ngắn thì không có tác dụng, quá dài thì user cảm thấy lag. Có thể adaptive — tăng interval khi network chậm.

**Batching cần backend hỗ trợ.** Nếu server không có batch endpoint, bạn có thể dùng GraphQL (gom nhiều query vào 1 request) hoặc thương lượng với backend team để tạo endpoint riêng.

**Kết hợp cả hai.** Trong thực tế, search bar nên debounce input, đồng thời nếu app có analytics events phát sinh liên tục, nên batch chúng lại rồi gửi một lượt (ví dụ mỗi 30 giây hoặc khi app vào background).

**Cancel semantics.** Luôn handle cancellation đúng cách. Với Combine dùng `switchToLatest`, với async/await kiểm tra `Task.isCancelled`. Memory leak từ continuation không được resume là crash tiềm ẩn rất khó debug.
