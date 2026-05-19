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
