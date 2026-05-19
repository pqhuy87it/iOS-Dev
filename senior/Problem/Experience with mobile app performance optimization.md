# Mobile App Performance Optimization — Góc nhìn Senior iOS Developer

Đây là một trong những kỹ năng cốt lõi phân biệt Senior với Junior/Mid-level. Nó bao gồm rất nhiều khía cạnh, mình sẽ đi sâu từng mảng.

---

## 1. Memory Optimization

**Vấn đề thường gặp:** Memory leaks, retain cycles, excessive memory footprint.

**Kỹ năng cần có:**

Hiểu rõ **ARC (Automatic Reference Counting)** và cách nó hoạt động ở level sâu. Senior phải biết khi nào dùng `weak`, `unowned`, và đặc biệt phải phát hiện được **retain cycle** trong các closure, delegate pattern, hay combine/RxSwift subscriptions.

Sử dụng thành thạo **Instruments — Leaks & Allocations** để track memory. Ví dụ, một màn hình chat load hàng nghìn tin nhắn, Senior cần biết cách dùng **cell reuse**, **lazy loading images**, và giới hạn số lượng object trong memory thông qua pagination hoặc diffable data source.

**Autorelease pool** cũng là một chủ đề quan trọng khi xử lý batch operations, ví dụ parse hàng nghìn JSON objects trong vòng lặp — nếu không wrap trong `autoreleasepool {}`, memory sẽ spike lên rất cao trước khi được giải phóng.

---

## 2. UI/Rendering Performance

**Mục tiêu:** Giữ cho app luôn chạy ở **60fps** (hoặc 120fps trên ProMotion devices), tức mỗi frame phải render trong khoảng **16.67ms**.

**Các vấn đề phổ biến:**

- **Offscreen rendering:** Khi dùng `cornerRadius` kết hợp `masksToBounds`, hoặc shadow không có `shadowPath`, GPU phải tạo buffer ngoài màn hình để composite — rất tốn. Senior cần biết cách pre-render hoặc rasterize layer (`shouldRasterize`).
- **Blending:** Nhiều layer transparent chồng lên nhau buộc GPU phải tính toán alpha blending. Dùng **Color Blended Layers** trong Simulator để debug.
- **Main thread blocking:** Bất kỳ heavy computation nào trên main thread đều gây jank. Senior phải biết cách dispatch sang background queue và chỉ update UI trên main.

**Công cụ:** Instruments — Core Animation, Time Profiler, GPU Driver. Ngoài ra, dùng `CADisplayLink` để monitor frame rate real-time.

---

## 3. Network Optimization

Senior cần optimize không chỉ tốc độ mà cả **data usage** và **battery impact:**

- **Request batching & debouncing:** Gộp nhiều request nhỏ thành một, hoặc debounce search input để tránh gọi API mỗi keystroke.
- **Caching strategy:** Hiểu rõ `URLCache`, HTTP cache headers (`ETag`, `Cache-Control`), và khi nào cần custom cache layer (dùng Core Data, Realm, hoặc file system).
- **Image optimization:** Dùng progressive JPEG, WebP format, resize ảnh về đúng kích thước hiển thị thay vì download ảnh gốc 4K rồi scale xuống. Thư viện như Kingfisher/SDWebImage hỗ trợ, nhưng Senior phải hiểu cơ chế bên dưới.
- **Certificate pinning & HTTP/2 multiplexing:** Vừa bảo mật vừa tận dụng multiplexing để giảm connection overhead.

---

## 4. App Launch Time Optimization

Apple đo launch time rất nghiêm ngặt. App mà launch > 400ms sẽ bị cảnh báo trong Xcode Organizer.

**Pre-main (trước khi `main()` chạy):**
- Giảm số lượng **dynamic frameworks** — mỗi dylib cần load và rebase/bind symbols.
- Tránh dùng quá nhiều `+load` methods trong Objective-C hoặc static initializers.
- Dùng `DYLD_PRINT_STATISTICS` environment variable để đo chính xác.

**Post-main (từ `main()` đến first frame):**
- Defer mọi thứ không cần thiết cho màn hình đầu tiên. Ví dụ: analytics SDK, crash reporting, feature flags — init chúng async sau khi UI đã hiển thị.
- Lazy initialization cho các service, dependency injection container chỉ resolve khi cần.

---

## 5. Battery & Thermal Optimization

Đây là thứ nhiều developer bỏ qua nhưng Apple rất quan tâm:

- Tránh **continuous location updates** khi chỉ cần significant changes.
- Dùng **background fetch** và **BGTaskScheduler** thay vì keep app alive liên tục.
- Monitor CPU usage — nếu app liên tục dùng >20% CPU khi idle, đó là vấn đề. Timer chạy liên tục, animation không dừng khi view không visible, hay combine/RxSwift subscription không dispose đúng cách đều gây hao pin.

---

## 6. Build & Binary Size Optimization

- **App Thinning:** Hiểu cách **Bitcode**, **Slicing**, và **On-Demand Resources** hoạt động.
- **Dead code elimination:** Dùng `DEAD_CODE_STRIPPING`, kiểm tra unused frameworks.
- **Asset catalog optimization:** Dùng đúng scale factors, tránh bundle assets không cần thiết.
- **Swift compiler flags:** `-Osize` cho optimize size, `-O` cho optimize speed.

---

## 7. Profiling Mindset & Tooling

Điều quan trọng nhất của Senior là **profiling-driven optimization** — không optimize mù mà phải đo trước, tìm bottleneck, rồi mới fix:

- **Instruments:** Time Profiler, Allocations, Leaks, Network, Energy Log, Core Animation, System Trace.
- **Xcode Organizer:** Xem metrics từ real users — launch time, hang rate, disk writes, memory.
- **MetricKit:** Collect performance diagnostics programmatically từ production.
- **os_signpost & Pointsof Interest:** Custom instrument markers để đo chính xác từng đoạn code.

---

## Tóm lại

Một Senior iOS Developer khi nói về "performance optimization" không chỉ là biết dùng `DispatchQueue.global()` hay cache ảnh. Đó là khả năng nhìn toàn diện hệ thống — từ memory, CPU, GPU, network, disk I/O, đến battery — và biết cách **đo lường, phân tích, tối ưu có hệ thống** dựa trên data thực tế, không phải cảm tính. Đồng thời, Senior cần biết **trade-off**: optimize quá sớm là lãng phí, nhưng để technical debt tích lũy sẽ rất khó fix sau này.

# 1. Request batching & debouncing: Gộp nhiều request nhỏ thành một tránh gọi API mỗi keystroke

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

# 2.Caching strategy: Hiểu rõ URLCache, HTTP cache headers (ETag, Cache-Control)

# Caching Strategy trong iOS

## 1. HTTP Caching — Nền tảng cần hiểu trước

Trước khi nói về code, cần hiểu **caching hoạt động ở tầng HTTP** như thế nào, vì `URLSession` của Apple tuân thủ theo chuẩn này.

### Luồng hoạt động cơ bản

```
Request lần 1:
Client ──GET /users/42──▶ Server
Client ◀──200 OK + ETag: "abc123" + Cache-Control: max-age=60── Server
       (Response được lưu vào cache)

Request lần 2 (trong vòng 60 giây):
Client ──kiểm tra cache──▶ Cache HIT → trả về ngay, KHÔNG gọi network
       (zero latency, zero bandwidth)

Request lần 3 (sau 60 giây, cache hết hạn):
Client ──GET /users/42 + If-None-Match: "abc123"──▶ Server
Client ◀──304 Not Modified── Server
       (Data chưa thay đổi, dùng lại cache, tiết kiệm bandwidth)
```

### Các HTTP Cache Header quan trọng

```
┌─────────────────────────────────────────────────────────────┐
│                   SERVER → CLIENT                           │
├─────────────────────────────────────────────────────────────┤
│ Cache-Control: max-age=3600        // Fresh trong 1 giờ     │
│ Cache-Control: no-cache            // Luôn validate lại     │
│ Cache-Control: no-store            // KHÔNG cache (nhạy cảm)│
│ Cache-Control: private             // Chỉ client cache      │
│ Cache-Control: public              // CDN cũng được cache   │
│ ETag: "v2-abc123"                  // Fingerprint của data  │
│ Last-Modified: Thu, 01 Jan 2026..  // Lần sửa cuối         │
├─────────────────────────────────────────────────────────────┤
│                   CLIENT → SERVER (validation)              │
├─────────────────────────────────────────────────────────────┤
│ If-None-Match: "v2-abc123"         // Gửi kèm ETag cũ      │
│ If-Modified-Since: Thu, 01 Jan..   // Gửi kèm timestamp cũ │
└─────────────────────────────────────────────────────────────┘
```

**`Cache-Control: no-cache` vs `no-store`** — đây là điểm hay bị hiểu sai:

- `no-cache`: vẫn **được lưu** vào cache, nhưng mỗi lần dùng phải **hỏi lại server** (validate). Nếu server trả 304, dùng cache → vẫn tiết kiệm bandwidth.
- `no-store`: **cấm lưu hoàn toàn**. Dùng cho data nhạy cảm như token, thông tin tài chính.

---

## 2. URLCache — Built-in Cache của Apple

### URLCache là gì?

`URLCache` là HTTP cache layer mà `URLSession` tự động sử dụng. Nó lưu response vào cả **memory** và **disk**, tuân thủ HTTP cache headers.

```swift
// Default cache — 4MB memory, 20MB disk
URLCache.shared

// Custom cache cho app cần cache lớn hơn
let cache = URLCache(
    memoryCapacity: 50 * 1024 * 1024,  // 50 MB RAM
    diskCapacity: 200 * 1024 * 1024,    // 200 MB disk
    directory: cacheDirectory
)
URLCache.shared = cache
```

### URLSession sử dụng URLCache như thế nào?

```swift
// Cache policy được set ở 2 nơi:

// 1. Cấp Session — áp dụng cho mọi request
let config = URLSessionConfiguration.default
config.requestCachePolicy = .returnCacheDataElseLoad
config.urlCache = customCache
let session = URLSession(configuration: config)

// 2. Cấp Request — override cho từng request cụ thể
var request = URLRequest(url: url)
request.cachePolicy = .reloadIgnoringLocalCacheData  // Bỏ qua cache
```

### Các Cache Policy quan trọng

```swift
// Dùng HTTP headers để quyết định (mặc định, khuyến nghị)
.useProtocolCachePolicy

// Có cache → dùng ngay, không cần validate
// (tốt cho offline mode, nhưng data có thể stale)
.returnCacheDataElseLoad

// Có cache → dùng, không có → cũng KHÔNG gọi network
// (pure offline — dùng khi biết chắc không có mạng)
.returnCacheDataDontLoad

// Bỏ qua cache, luôn gọi network
// (dùng cho pull-to-refresh, force reload)
.reloadIgnoringLocalCacheData
```

### Ví dụ thực tế: API client thông minh

```swift
class APIClient {
    private let session: URLSession
    private let cache: URLCache
    
    init() {
        self.cache = URLCache(
            memoryCapacity: 30 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024
        )
        let config = URLSessionConfiguration.default
        config.urlCache = self.cache
        config.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: config)
    }
    
    func fetch<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        forceRefresh: Bool = false
    ) async throws -> (T, DataSource) {
        var request = URLRequest(url: url)
        
        if forceRefresh {
            // Pull-to-refresh: bỏ qua cache
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }
        
        let (data, response) = try await session.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        
        let source: DataSource = httpResponse.statusCode == 304
            ? .cache      // Server confirm cache còn valid
            : .network    // Data mới từ server
        
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return (decoded, source)
    }
    
    /// Đọc cache mà không gọi network (cho offline)
    func cachedResponse(for url: URL) -> CachedURLResponse? {
        let request = URLRequest(url: url)
        return cache.cachedResponse(for: request)
    }
}

enum DataSource {
    case cache, network
}
```

### Hạn chế của URLCache

```
┌────────────────────────────────────────────────────────────┐
│ URLCache KHÔNG phù hợp khi:                               │
│                                                            │
│ ❌ Cần query data (tìm user theo tên, filter theo date)   │
│ ❌ Cần partial update (sửa 1 field, không fetch lại cả    │
│    response)                                               │
│ ❌ Cần relationship giữa các entity (user → posts → cmts) │
│ ❌ Cần cache survive qua app reinstall                     │
│ ❌ Server không trả cache headers đúng chuẩn               │
│ ❌ Cần invalidate cache theo business logic phức tạp       │
│                                                            │
│ → Khi gặp các case này, cần Custom Cache Layer             │
└────────────────────────────────────────────────────────────┘
```

---

## 3. Custom Cache Layer

### Khi nào cần?

Khi app có yêu cầu vượt quá khả năng của URLCache — offline-first, complex queries, relational data, hoặc fine-grained invalidation.

### Option A: Core Data

**Phù hợp cho:** relational data, complex queries, large dataset, Apple ecosystem thuần.

```swift
// MARK: - Entity
@objc(CachedUser)
class CachedUser: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var avatarURL: String
    @NSManaged var lastFetchedAt: Date
    @NSManaged var posts: NSSet?  // Relationship
}

// MARK: - Repository pattern
class UserRepository {
    private let context: NSManagedObjectContext
    private let apiClient: APIClient
    
    // Cache TTL — data cũ hơn 5 phút coi như stale
    private let cacheTTL: TimeInterval = 5 * 60
    
    func getUser(id: String) async throws -> User {
        // 1. Kiểm tra cache trước
        if let cached = fetchFromCache(id: id),
           !isStale(cached) {
            return cached.toDomain()
        }
        
        // 2. Cache miss hoặc stale → gọi API
        do {
            let dto = try await apiClient.fetchUser(id: id)
            let cached = saveToCache(dto)
            return cached.toDomain()
        } catch {
            // 3. Network fail → fallback về stale cache
            //    (stale data tốt hơn no data)
            if let staleCache = fetchFromCache(id: id) {
                return staleCache.toDomain()
            }
            throw error
        }
    }
    
    private func isStale(_ entity: CachedUser) -> Bool {
        Date().timeIntervalSince(entity.lastFetchedAt) > cacheTTL
    }
    
    private func fetchFromCache(id: String) -> CachedUser? {
        let request = CachedUser.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? context.fetch(request).first
    }
    
    private func saveToCache(_ dto: UserDTO) -> CachedUser {
        let entity = CachedUser(context: context)
        entity.id = dto.id
        entity.name = dto.name
        entity.avatarURL = dto.avatarURL
        entity.lastFetchedAt = Date()
        try? context.save()
        return entity
    }
}
```

### Option B: File System

**Phù hợp cho:** large blobs (images, JSON responses, PDF), simple key-value, không cần query.

```swift
actor DiskCache<T: Codable> {
    
    private let directory: URL
    private let maxAge: TimeInterval
    private let maxSize: Int  // bytes
    
    init(name: String, maxAge: TimeInterval = 3600, maxSize: Int = 50_000_000) {
        self.directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        self.maxAge = maxAge
        self.maxSize = maxSize
        
        try? FileManager.default
            .createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    func get(key: String) throws -> T? {
        let fileURL = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Kiểm tra expiry bằng file attributes
        let attrs = try FileManager.default
            .attributesOfItem(atPath: fileURL.path)
        if let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > maxAge {
            try? FileManager.default.removeItem(at: fileURL)
            return nil  // Expired
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func set(key: String, value: T) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: fileURL(for: key))
    }
    
    /// LRU eviction — gọi định kỳ hoặc khi app nhận memory warning
    func evictIfNeeded() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [
                .contentModificationDateKey, .fileSizeKey
            ])
        
        // Sắp xếp theo thời gian truy cập, cũ nhất trước
        let sorted = files.sorted {
            let d1 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let d2 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return d1 < d2
        }
        
        var totalSize = sorted.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return sum + size
        }
        
        // Xóa file cũ nhất cho đến khi dưới maxSize
        for file in sorted where totalSize > maxSize {
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try? FileManager.default.removeItem(at: file)
            totalSize -= size
        }
    }
    
    private func fileURL(for key: String) -> URL {
        // SHA256 hash key để tránh illegal characters trong filename
        let hashed = key.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent(hashed)
    }
}
```

### Option C: In-Memory Cache (NSCache)

**Phù hợp cho:** data nhỏ, truy cập thường xuyên, chấp nhận mất khi app bị kill.

```swift
class MemoryCache<Key: Hashable, Value> {
    
    private let cache = NSCache<WrappedKey, WrappedValue>()
    
    init(countLimit: Int = 100, totalCostLimit: Int = 10_000_000) {
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit // bytes
    }
    
    subscript(key: Key) -> Value? {
        get { cache.object(forKey: WrappedKey(key))?.value }
        set {
            if let value = newValue {
                cache.setObject(WrappedValue(value), forKey: WrappedKey(key))
            } else {
                cache.removeObject(forKey: WrappedKey(key))
            }
        }
    }
    
    // NSCache yêu cầu key là NSObject subclass
    private class WrappedKey: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            (object as? WrappedKey)?.key == key
        }
    }
    
    private class WrappedValue {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
}
```

Ưu điểm của `NSCache` so với `Dictionary`: hệ thống **tự động evict** khi memory pressure cao — không cần tự quản lý.

---

## 4. Multi-Layer Cache Architecture

Trong production app, thường kết hợp nhiều layer:

```
┌──────────────────────────────────────────────────────┐
│                    Request đến                        │
│                        │                              │
│                        ▼                              │
│  ┌──────────────────────────┐                        │
│  │   L1: NSCache (Memory)   │  ~0ms, mất khi kill   │
│  │   Hot data, decoded obj  │                        │
│  └────────────┬─────────────┘                        │
│          miss │                                       │
│               ▼                                       │
│  ┌──────────────────────────┐                        │
│  │   L2: Disk Cache / DB    │  ~1-5ms, persist       │
│  │   Raw JSON hoặc entities │                        │
│  └────────────┬─────────────┘                        │
│          miss │                                       │
│               ▼                                       │
│  ┌──────────────────────────┐                        │
│  │   L3: URLCache (HTTP)    │  Tuân thủ ETag/CC      │
│  │   Cả memory + disk       │                        │
│  └────────────┬─────────────┘                        │
│          miss │                                       │
│               ▼                                       │
│  ┌──────────────────────────┐                        │
│  │   L4: Network            │  ~100-2000ms           │
│  │   Kết quả lưu ngược lên  │                        │
│  └──────────────────────────┘                        │
└──────────────────────────────────────────────────────┘
```

Implementation:

```swift
class LayeredRepository<T: Codable & Identifiable> {
    
    private let memoryCache = MemoryCache<String, T>()
    private let diskCache: DiskCache<T>
    private let apiClient: APIClient
    
    init(cacheName: String, apiClient: APIClient) {
        self.diskCache = DiskCache(name: cacheName)
        self.apiClient = apiClient
    }
    
    func get(id: String, url: URL, forceRefresh: Bool = false) async throws -> T {
        // L1: Memory
        if !forceRefresh, let cached = memoryCache[id] {
            return cached
        }
        
        // L2: Disk
        if !forceRefresh, let cached = try await diskCache.get(key: id) {
            memoryCache[id] = cached  // Promote lên L1
            return cached
        }
        
        // L3+L4: Network (URLCache xử lý HTTP caching tự động)
        let (result, _) = try await apiClient.fetch(T.self, from: url)
        
        // Lưu ngược lên các layer
        memoryCache[id] = result
        try await diskCache.set(key: id, value: result)
        
        return result
    }
}
```

---

## 5. Cache Invalidation

> *"There are only two hard things in Computer Science: cache invalidation and naming things."*

### Các strategy phổ biến

```swift
enum InvalidationStrategy {
    
    /// Time-based: đơn giản nhất
    /// Dùng cho data ít thay đổi (config, feature flags)
    case ttl(seconds: TimeInterval)
    
    /// Event-based: chính xác nhất
    /// Dùng khi app biết chính xác khi nào data thay đổi
    case onEvent  // user edit profile → invalidate profile cache
    
    /// Version-based: server driven
    /// ETag hoặc custom version number
    case versionCheck
    
    /// Stale-while-revalidate: UX tốt nhất
    /// Trả cache cũ ngay cho UI, đồng thời fetch mới ở background
    case staleWhileRevalidate
}
```

### Stale-While-Revalidate — Pattern hay dùng nhất

```swift
class StaleWhileRevalidateCache<T: Codable & Equatable> {
    
    private let diskCache: DiskCache<Timestamped<T>>
    private let freshAge: TimeInterval  // coi là fresh trong bao lâu
    
    struct Timestamped<V: Codable>: Codable {
        let value: V
        let fetchedAt: Date
    }
    
    func get(
        key: String,
        fetcher: () async throws -> T,
        onUpdate: @MainActor (T) -> Void
    ) async throws -> T {
        
        // 1. Trả cache ngay nếu có (dù stale)
        if let cached = try await diskCache.get(key: key) {
            let isFresh = Date().timeIntervalSince(cached.fetchedAt) < freshAge
            
            if isFresh {
                return cached.value  // Fresh → xong
            }
            
            // Stale → trả ngay cho UI, revalidate ở background
            Task {
                if let fresh = try? await fetcher() {
                    let stamped = Timestamped(value: fresh, fetchedAt: Date())
                    try? await diskCache.set(key: key, value: stamped)
                    // Chỉ update UI nếu data thực sự thay đổi
                    if fresh != cached.value {
                        await onUpdate(fresh)
                    }
                }
            }
            
            return cached.value
        }
        
        // 2. Không có cache → bắt buộc fetch
        let fresh = try await fetcher()
        let stamped = Timestamped(value: fresh, fetchedAt: Date())
        try await diskCache.set(key: key, value: stamped)
        return fresh
    }
}
```

Từ phía user: mở app → thấy data ngay (stale cache) → vài trăm ms sau data tự cập nhật nếu có thay đổi. Không có loading spinner, không có blank screen.

---

## 6. Tổng kết — Decision Framework

```
Cần cache HTTP response đơn giản?
  → URLCache + đảm bảo server trả đúng headers

Cần offline support cơ bản, key-value?
  → File system (DiskCache)

Cần query, filter, relationship?
  → Core Data (hoặc SwiftData cho project mới)

Cần cache decoded object, truy cập cực nhanh?
  → NSCache (memory-only, auto-evict)

Cần UX mượt, không loading spinner?
  → Stale-while-revalidate pattern

App phức tạp, production-grade?
  → Multi-layer: NSCache + Disk + URLCache + Network
```

**Điểm mấu chốt cho Senior**: không có silver bullet. Chọn strategy dựa trên đặc thù data (tần suất thay đổi, kích thước, có cần query không), yêu cầu UX (offline? instant load?), và khả năng của backend (có hỗ trợ ETag/Cache-Control không). Phần lớn bug liên quan cache đều đến từ invalidation sai — nên ưu tiên strategy đơn giản, dễ reason about, rồi tối ưu sau.

# 3.Image optimization

# Image Optimization trong iOS

## 1. Tại sao Image Optimization quan trọng?

### Bài toán thực tế

Một màn hình feed hiển thị 10 ảnh, mỗi ảnh server trả về 4K (3840×2160). Thiết bị hiển thị trong UIImageView 375×200 points (@3x = 1125×600 pixels).

```
Ảnh gốc 4K JPEG:     ~3-5 MB × 10 ảnh = 30-50 MB bandwidth
Decoded in memory:    3840 × 2160 × 4 bytes = ~33 MB mỗi ảnh
                      10 ảnh = ~330 MB RAM ← OOM crash trên
                      iPhone cũ

Ảnh resize về 1125×600:  ~100-200 KB × 10 = 1-2 MB bandwidth  
Decoded in memory:        1125 × 600 × 4 = ~2.7 MB mỗi ảnh
                          10 ảnh = ~27 MB RAM ← hoàn toàn OK
```

**Tại sao decoded size lớn hơn file size nhiều như vậy?**

JPEG/WebP trên disk là dạng **compressed**. Khi hiển thị, GPU cần **uncompressed bitmap** — mỗi pixel cần 4 bytes (RGBA). Đây là điểm nhiều developer bỏ qua: file nhỏ không có nghĩa là memory footprint nhỏ.

---

## 2. Image Formats — Hiểu bản chất

### JPEG chuẩn (Baseline)

```
Cách decode Baseline JPEG:

  Scan 1 (duy nhất): ████████████████████████████████ 100%
                      ↑                                ↑
                   Bắt đầu                     Xong → hiển thị

  User thấy: [        trống        ] → [   ảnh hoàn chỉnh   ]
              Loading...                  Xuất hiện đột ngột
```

Ảnh được encode **từ trên xuống dưới**, scan line by line. Phải download xong toàn bộ mới decode được đầy đủ. Nếu network chậm, user nhìn thấy ảnh "rơi" từ trên xuống hoặc không thấy gì cho đến khi xong.

### Progressive JPEG

```
Cách decode Progressive JPEG:

  Scan 1:  ░░░░░░░░░░░░░░░░░░  Toàn bộ ảnh, cực mờ (DC coefficients)
  Scan 2:  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒  Rõ hơn một chút (low-frequency AC)
  Scan 3:  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  Gần rõ (mid-frequency AC)
  Scan 4:  ████████████████████  Sắc nét hoàn toàn (high-frequency AC)

  User thấy: [ mờ ] → [ rõ hơn ] → [ gần rõ ] → [ sắc nét ]
              ← Perceived loading time ngắn hơn nhiều →
```

**Cơ chế bên trong:** JPEG sử dụng DCT (Discrete Cosine Transform) để chuyển pixel thành frequency coefficients. Progressive JPEG sắp xếp lại thứ tự encode: gửi **low-frequency coefficients trước** (hình dạng tổng thể, màu chủ đạo), rồi dần bổ sung **high-frequency** (chi tiết, edges, texture).

```swift
// Tạo Progressive JPEG từ UIImage
func progressiveJPEGData(from image: UIImage, quality: CGFloat = 0.8) -> Data? {
    guard let cgImage = image.cgImage else { return nil }
    
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        data, kUTTypeJPEG, 1, nil
    ) else { return nil }
    
    let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: quality,
        kCGImagePropertyJFIFDictionary: [
            kCGImagePropertyJFIFIsProgressive: true
        ]
    ]
    
    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    return data as Data
}
```

### WebP

```
┌────────────────────────────────────────────────────────────┐
│ So sánh format ở cùng chất lượng visual (SSIM ~0.95)      │
│                                                            │
│ Format          │ File Size │ Decode Speed │ iOS Support   │
│─────────────────┼───────────┼──────────────┼──────────────│
│ JPEG             │ 100 KB    │ Nhanh        │ Mọi version  │
│ Progressive JPEG │ 102 KB    │ Chậm hơn ~5% │ Mọi version  │
│ WebP (lossy)     │ 70 KB     │ Chậm hơn ~10%│ iOS 14+      │
│ WebP (lossless)  │ 85 KB     │ Chậm hơn ~15%│ iOS 14+      │
│ HEIF/HEIC        │ 65 KB     │ Hardware acc. │ iOS 11+      │
│ AVIF             │ 55 KB     │ Chậm         │ iOS 16+      │
└────────────────────────────────────────────────────────────┘
```

**WebP nhỏ hơn JPEG ~25-35%** ở cùng chất lượng vì sử dụng VP8 codec (prediction-based, tương tự video compression), trong khi JPEG dùng DCT thuần. Tuy nhiên decode chậm hơn vì không có hardware acceleration trên hầu hết iPhone (HEIF thì có).

```swift
// iOS 14+ decode WebP natively
let webpData: Data = ... // từ network
let image = UIImage(data: webpData) // Just works

// Kiểm tra format support
import UniformTypeIdentifiers
let webpSupported = CGImageSourceCopyTypeIdentifiers() as? [String] ?? []
print(webpSupported.contains("org.webmproject.webp")) // true trên iOS 14+
```

**Trade-off quan trọng:** WebP tiết kiệm bandwidth (tốt cho user data plan) nhưng tốn CPU hơn khi decode (tốn pin). Cần benchmark trên target device thấp nhất của app.

---

## 3. Resize về đúng kích thước hiển thị

### Vấn đề cốt lõi

```swift
// ❌ Cách phổ biến nhưng rất tốn resource
let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 375, height: 200))
imageView.contentMode = .scaleAspectFill

// Download ảnh 4K (3840×2160), UIImageView tự scale xuống khi render
// Nhưng trong memory, ảnh 4K vẫn chiếm 33MB!
imageView.image = fullResImage
```

UIKit không tự resize ảnh trong memory. `contentMode = .scaleAspectFill` chỉ yêu cầu **GPU scale khi render** — bitmap gốc vẫn nằm nguyên trong RAM.

### Downsampling đúng cách — ImageIO

```swift
enum ImageDownsampler {
    
    /// Downsampling bằng ImageIO — KHÔNG load full image vào memory
    static func downsample(
        data: Data,
        to pointSize: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> UIImage? {
        
        let pixelSize = CGSize(
            width: pointSize.width * scale,
            height: pointSize.height * scale
        )
        
        let options: [CFString: Any] = [
            // Cho phép cache decoded image
            kCGImageSourceShouldCache: false,
            // QUAN TRỌNG: không decode full image trước
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Resize ngay ở tầng codec, TRƯỚC khi load vào memory
            kCGImageSourceThumbnailMaxPixelSize: max(pixelSize.width, pixelSize.height),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
```

**Tại sao ImageIO chứ không phải `UIGraphicsImageRenderer`?**

```swift
// ❌ UIGraphicsImageRenderer — phải decode TOÀN BỘ ảnh gốc trước
func resizeBad(image: UIImage, to size: CGSize) -> UIImage {
    // Bước 1: UIImage đã decode full 33MB vào memory
    // Bước 2: Vẽ lại vào canvas mới → peak memory = 33MB + 2.7MB
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
}

// ✅ ImageIO — decode trực tiếp ở kích thước nhỏ
// Peak memory chỉ ~2.7MB, không bao giờ load 33MB
let small = ImageDownsampler.downsample(data: rawData, to: CGSize(width: 375, height: 200))
```

Điểm mấu chốt: `CGImageSourceCreateThumbnailAtIndex` hoạt động ở **tầng codec** — nó đọc JPEG data và decode thẳng ra thumbnail mà không cần giải nén full resolution trước. Đây là cách tiết kiệm memory nhất.

### Server-side resize — Giải pháp tốt nhất

Thay vì client tự resize, yêu cầu server trả ảnh đúng kích thước:

```swift
// Nhiều CDN/image service hỗ trợ resize qua URL params
enum ImageURLBuilder {
    
    static func optimizedURL(
        original: URL,
        pointSize: CGSize,
        scale: CGFloat = UIScreen.main.scale
    ) -> URL {
        let pixelWidth = Int(pointSize.width * scale)
        let pixelHeight = Int(pointSize.height * scale)
        
        // Cloudinary style
        // https://res.cloudinary.com/demo/image/upload/w_1125,h_600,c_fill,q_auto,f_auto/sample.jpg
        var components = URLComponents(url: original, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "w", value: "\(pixelWidth)"),
            URLQueryItem(name: "h", value: "\(pixelHeight)"),
            URLQueryItem(name: "fit", value: "cover"),
            URLQueryItem(name: "format", value: "auto"),  // Server chọn WebP nếu client hỗ trợ
            URLQueryItem(name: "quality", value: "auto")   // Server chọn quality tối ưu
        ]
        return components.url!
    }
}

// Sử dụng
let thumbnailURL = ImageURLBuilder.optimizedURL(
    original: originalURL,
    pointSize: imageView.bounds.size
)
// Download 100KB thay vì 5MB
```

`f_auto` (format auto) là feature quan trọng: server tự detect client support và trả WebP cho iOS 14+, AVIF cho iOS 16+, fallback JPEG cho device cũ. Client không cần xử lý gì thêm.

---

## 4. Cơ chế bên trong Kingfisher/SDWebImage

Cả hai thư viện đều follow cùng một architecture. Hiểu flow này giúp debug production issues và biết khi nào cần customize.

### Pipeline tổng quan

```
imageView.kf.setImage(with: url)
                │
                ▼
┌─────────────────────────────┐
│  1. Check Memory Cache      │  NSCache<URL, UIImage>
│     (decoded UIImage)       │  → HIT: return ngay, ~0ms
└──────────────┬──────────────┘
           MISS│
               ▼
┌─────────────────────────────┐
│  2. Check Disk Cache        │  File system, keyed by URL hash
│     (encoded Data)          │  → HIT: decode → memory cache → return
└──────────────┬──────────────┘
           MISS│
               ▼
┌─────────────────────────────┐
│  3. Download                │  URLSession data task
│     (raw bytes)             │  Concurrent, có priority queue
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  4. Process                 │  Resize, round corners, blur...
│     (trên background queue) │  Xảy ra TRƯỚC khi cache
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  5. Cache                   │  Lưu vào cả memory + disk
│                             │  Memory: processed UIImage
│                             │  Disk: processed Data (re-encoded)
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  6. Display                 │  Main thread
│     (fade transition)       │  imageView.image = processed
└─────────────────────────────┘
```

### Tự implement để hiểu từng phần

```swift
actor ImagePipeline {
    
    // MARK: - Memory Cache (L1)
    // Lưu decoded UIImage, truy cập ~0ms
    // NSCache tự evict khi memory pressure
    private let memoryCache = NSCache<NSString, UIImage>()
    
    // MARK: - Disk Cache (L2)
    // Lưu encoded data (JPEG/WebP bytes), persist qua app launch
    private let diskCacheDir: URL
    
    // MARK: - Deduplication
    // Tránh download cùng URL nhiều lần đồng thời
    private var inFlightTasks: [URL: Task<UIImage, Error>] = [:]
    
    // MARK: - Main Entry Point
    func image(
        for url: URL,
        targetSize: CGSize? = nil
    ) async throws -> UIImage {
        let cacheKey = cacheKey(url: url, size: targetSize)
        
        // L1: Memory
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            return cached
        }
        
        // L2: Disk
        if let data = diskData(for: cacheKey),
           let image = processData(data, targetSize: targetSize) {
            memoryCache.setObject(image, forKey: cacheKey as NSString)
            return image
        }
        
        // Deduplication: nếu đang download URL này rồi, chờ kết quả
        if let existing = inFlightTasks[url] {
            return try await existing.value
        }
        
        // Download
        let task = Task {
            try await downloadAndProcess(url: url, cacheKey: cacheKey, targetSize: targetSize)
        }
        inFlightTasks[url] = task
        
        defer { inFlightTasks[url] = nil }
        return try await task.value
    }
    
    // MARK: - Download + Process
    private func downloadAndProcess(
        url: URL,
        cacheKey: String,
        targetSize: CGSize?
    ) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Downsample bằng ImageIO (KHÔNG load full res vào memory)
        guard let image = processData(data, targetSize: targetSize) else {
            throw ImageError.decodeFailed
        }
        
        // Cache: disk lưu data gốc, memory lưu processed image
        saveToDisk(data: data, key: cacheKey)
        memoryCache.setObject(image, forKey: cacheKey as NSString)
        
        return image
    }
    
    // MARK: - Processing
    private func processData(_ data: Data, targetSize: CGSize?) -> UIImage? {
        if let size = targetSize {
            return ImageDownsampler.downsample(data: data, to: size)
        }
        return UIImage(data: data)
    }
    
    // MARK: - Cache Key
    // Cùng URL nhưng khác targetSize → khác cache entry
    private func cacheKey(url: URL, size: CGSize?) -> String {
        if let size {
            return "\(url.absoluteString)_\(Int(size.width))x\(Int(size.height))"
        }
        return url.absoluteString
    }
}
```

### Request Deduplication — Chi tiết quan trọng

```
Không có deduplication:
  Cell 1 ──GET avatar.jpg──▶ Server
  Cell 2 ──GET avatar.jpg──▶ Server    (cùng URL!)
  Cell 3 ──GET avatar.jpg──▶ Server    (cùng URL!)
  = 3 request, 3× bandwidth

Có deduplication:
  Cell 1 ──GET avatar.jpg──▶ Server
  Cell 2 ──chờ Cell 1────▶ (reuse response)
  Cell 3 ──chờ Cell 1────▶ (reuse response)
  = 1 request, chia sẻ kết quả
```

Khi user scroll nhanh, cùng một avatar URL có thể bị request bởi nhiều cell gần như đồng thời (do cell reuse). Deduplication đảm bảo chỉ có **1 network request** cho mỗi unique URL tại bất kỳ thời điểm nào.

### Prefetching — Tích hợp UICollectionView

```swift
class FeedViewController: UIViewController {
    
    private let pipeline = ImagePipeline()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.prefetchDataSource = self
    }
}

extension FeedViewController: UICollectionViewDataSourcePrefetching {
    
    // Gọi khi cell SẮP scroll vào viewport
    func collectionView(
        _ collectionView: UICollectionView,
        prefetchItemsAt indexPaths: [IndexPath]
    ) {
        for indexPath in indexPaths {
            let item = items[indexPath.item]
            let size = cellImageSize(for: indexPath)
            
            // Bắt đầu download + process TRƯỚC khi cell hiển thị
            Task(priority: .utility) {
                _ = try? await pipeline.image(
                    for: item.imageURL,
                    targetSize: size
                )
            }
        }
    }
    
    // Gọi khi user đổi hướng scroll → cell không cần nữa
    func collectionView(
        _ collectionView: UICollectionView,
        cancelPrefetchingForItemsAt indexPaths: [IndexPath]
    ) {
        // Cancel task cho cell không còn cần
        // Tiết kiệm bandwidth + CPU cho cell thực sự hiển thị
    }
}
```

---

## 5. Memory Footprint — Phân tích chi tiết

### Tính toán thực tế

```swift
enum ImageMemoryCalculator {
    
    /// Tính memory footprint của decoded image
    static func decodedSize(
        width: Int,
        height: Int,
        bytesPerPixel: Int = 4  // RGBA
    ) -> Int {
        width * height * bytesPerPixel
    }
    
    /// Ví dụ thực tế
    static func examples() {
        // Thumbnail 100×100
        // = 100 × 100 × 4 = 40 KB ← không đáng kể
        
        // Feed image 1125×600 (@3x cho 375pt)
        // = 1125 × 600 × 4 = 2.7 MB ← hợp lý
        
        // Ảnh gốc 4K 3840×2160
        // = 3840 × 2160 × 4 = 33.2 MB ← NGUY HIỂM
        
        // Photo gallery 10 ảnh 4K
        // = 33.2 × 10 = 332 MB ← OOM crash
    }
}
```

### Giảm bytes-per-pixel khi không cần full color

```swift
// Ảnh grayscale hoặc ảnh không cần alpha
func downsampleOptimized(data: Data, to size: CGSize) -> UIImage? {
    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    
    // Dùng UIGraphicsImageRenderer với preferred format
    // .range giảm từ 4 bytes/pixel → 2 bytes (16-bit color)
    // Phù hợp cho thumbnail nhỏ, mắt không phân biệt được
    let renderer = UIGraphicsImageRenderer(
        size: size,
        format: {
            let fmt = UIGraphicsImageRendererFormat()
            fmt.preferredRange = .automatic  // System chọn optimal
            return fmt
        }()
    )
    
    return renderer.image { context in
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
    }
}
```

---

## 6. Tổng kết — Checklist cho Senior

```
┌─ BANDWIDTH ─────────────────────────────────────────────┐
│ □ Server-side resize (CDN params: w, h, format=auto)    │
│ □ WebP/AVIF với fallback JPEG                           │
│ □ Quality parameter tùy context (thumbnail 60%, full 80%)│
│ □ Progressive JPEG cho ảnh lớn, hero image              │
└─────────────────────────────────────────────────────────┘

┌─ MEMORY ────────────────────────────────────────────────┐
│ □ ImageIO downsampling (KHÔNG dùng UIImage init rồi     │
│   resize sau)                                           │
│ □ Cache key bao gồm target size                         │
│ □ NSCache auto-evict khi memory warning                 │
│ □ Monitor decoded size, không chỉ file size             │
└─────────────────────────────────────────────────────────┘

┌─ UX ────────────────────────────────────────────────────┐
│ □ Prefetch trước khi cell visible                       │
│ □ Cancel khi scroll direction thay đổi                  │
│ □ Placeholder / blur-up transition                      │
│ □ Request deduplication tránh duplicate download         │
└─────────────────────────────────────────────────────────┘

┌─ PRODUCTION ────────────────────────────────────────────┐
│ □ Disk cache eviction policy (LRU, max size)            │
│ □ Instrument bằng MetricKit / os_signpost               │
│ □ Benchmark decode time trên device thấp nhất           │
│ □ A/B test format + quality để tìm sweet spot           │
└─────────────────────────────────────────────────────────┘
```

Dùng Kingfisher hay SDWebImage đều tốt cho productivity, nhưng Senior cần hiểu pipeline bên trong để: (1) debug khi cache không hoạt động đúng, (2) custom processor cho use case đặc biệt, (3) tối ưu memory cho device cũ, và (4) phối hợp với backend team để đưa ra image serving strategy đúng đắn ngay từ đầu thay vì fix ở client.

# 4.Certificate pinning & HTTP/2 multiplexing

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
