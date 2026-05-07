# Swift Concurrency: `actor` — Giải thích chi tiết

## 1. Vấn đề actor giải quyết — Data Race

### Data Race là gì?

Khi **nhiều thread đồng thời** đọc/ghi cùng một mutable state mà **không có đồng bộ**, kết quả trở nên unpredictable:

```swift
// ❌ NGUY HIỂM: class thường, không bảo vệ
class UnsafeGeocoder {
    private var cachedResults: [String: String] = [:]  // shared mutable state
    
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        let key = "\(coord.latitude),\(coord.longitude)"
        
        if let cached = cachedResults[key] { return cached }
        // ↑ Thread A đọc: chưa có cache
        //                  Thread B cũng đọc: chưa có cache
        
        let result = try await doGeocode(coord)
        cachedResults[key] = result    // Thread A ghi
        //                                Thread B cũng ghi ← DATA RACE 💥
        return result
    }
}
```

Trước Swift Concurrency, phải tự xử lý bằng `DispatchQueue`, lock, semaphore — dễ quên, dễ sai.

### Giải pháp truyền thống vs Actor

```swift
// Cách cũ: tự quản lý lock
class ThreadSafeGeocoder {
    private let queue = DispatchQueue(label: "geocoder.serial")
    private var cache: [String: String] = [:]
    
    func lookup(_ key: String) -> String? {
        queue.sync { cache[key] }           // phải nhớ dùng queue
    }
    func store(_ key: String, _ value: String) {
        queue.sync { cache[key] = value }   // quên → data race
    }
}

// Cách mới: actor tự bảo vệ
actor SafeGeocoder {
    private var cache: [String: String] = [:]
    
    func lookup(_ key: String) -> String? {
        cache[key]                          // tự động serial, không cần lock
    }
    func store(_ key: String, _ value: String) {
        cache[key] = value                  // tự động serial
    }
}
```

---

## 2. `actor` là gì?

`actor` là **reference type** (như `class`) nhưng có thêm **cơ chế bảo vệ tự động**: mọi truy cập vào mutable state bên trong đều được **serialized** — chỉ một "người" được thực thi bên trong actor tại một thời điểm.

```swift
actor CoreLocationGeocoder {
    //  ↑ Khai báo giống class, nhưng dùng keyword "actor"
    
    private var requestCount = 0    // mutable state
    
    func reverseGeocode(...) async throws -> String {
        requestCount += 1           // an toàn, actor đảm bảo serial access
        // ...
    }
}
```

### So sánh cú pháp với class

```
class MyClass {              actor MyActor {
    var state = 0                var state = 0
    func doWork() { }            func doWork() { }
    init() { }                   init() { }
}                            }

        │                              │
        ▼                              ▼
  Reference type ✅              Reference type ✅
  Inheritance ✅                 Inheritance ❌ (không kế thừa actor khác)
  Protocol conform ✅            Protocol conform ✅
  Không bảo vệ data ❌          Tự động serial access ✅
  Sendable? ❌ (thường)         Sendable ✅ (tự động)
```

---

## 3. Cơ chế hoạt động — Actor Isolation

### Nguyên tắc cốt lõi

Actor có một **serial executor** nội bộ — tương tự serial DispatchQueue. Mọi method call từ **bên ngoài** actor phải **xếp hàng chờ** (await):

```
Bên ngoài actor                    Bên trong actor
───────────────                    ────────────────
                                   ┌─────────────────┐
Task A: await geocoder.reverse()──▶│ Executing Task A │
                                   │ requestCount += 1│
Task B: await geocoder.reverse()   │ ...              │
         │                         └────────┬──────────┘
         │ chờ (suspend)                    │ xong
         │                         ┌────────▼──────────┐
         └────────────────────────▶│ Executing Task B  │
                                   │ requestCount += 1 │
                                   └───────────────────┘
```

Không có hai Task nào **đồng thời** chạy bên trong actor → **không data race**.

### Truy cập từ bên ngoài: BẮT BUỘC `await`

```swift
let geocoder = CoreLocationGeocoder()

// Từ bên ngoài actor → phải await
let address = try await geocoder.reverseGeocode(coordinate)
//                ↑ await vì compiler biết đây là cross-actor call
//                  Task hiện tại SUSPEND cho đến khi actor sẵn sàng
```

### Truy cập từ bên trong: KHÔNG cần `await`

```swift
actor CoreLocationGeocoder {
    private var cache: [String: String] = [:]
    
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        let key = "\(coord.latitude),\(coord.longitude)"
        
        // Đang ở TRONG actor → truy cập trực tiếp, không await
        if let cached = cache[key] {
            return cached
        }
        
        let result = try await doActualGeocode(coord)
        cache[key] = result    // ghi trực tiếp, an toàn
        return result
    }
    
    private func doActualGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        // cũng trong actor → gọi trực tiếp
    }
}
```

### Actor re-entrancy — Điểm quan trọng

Khi gặp `await` **bên trong** actor method, actor **nhả lock** cho task khác chạy:

```swift
actor ImageCache {
    private var cache: [URL: UIImage] = [:]
    
    func getImage(for url: URL) async throws -> UIImage {
        if let cached = cache[url] { return cached }
        
        // ⚠️ await → actor NHẢO lock → task khác có thể chạy
        let image = try await downloadImage(url)
        
        // ← Khi quay lại đây, state CÓ THỂ ĐÃ THAY ĐỔI
        // Task khác có thể đã ghi cache[url] rồi
        cache[url] = image   // nên check lại nếu cần
        return image
    }
}
```

```
Task A: getImage(url1)
  → cache miss
  → await downloadImage(url1)    ← actor nhả lock
                                      │
Task B: getImage(url1)               │ Task B chạy ngay
  → cache miss (Task A chưa ghi)     │
  → await downloadImage(url1)    ← actor nhả lock
                                      │
Task A quay lại → ghi cache           │
Task B quay lại → ghi cache (lần 2)   │
→ Không crash (serial), nhưng download 2 lần (không tối ưu)
```

→ **Actor bảo vệ khỏi data race, KHÔNG bảo vệ khỏi logic race.** Cần xử lý thêm nếu muốn tránh duplicate work.

---

## 4. Phân tích đoạn code

### Protocol: `Sendable`

```swift
protocol LocationGeocoding: Sendable {
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String
}
```

`Sendable` đánh dấu: "Type này **an toàn khi truyền giữa các concurrency domain** (actor, task, thread khác nhau)." Là yêu cầu cơ bản của Swift Concurrency — nếu một object được chia sẻ giữa nhiều Task, nó phải `Sendable`.

### Actor tự động Sendable

```swift
actor CoreLocationGeocoder: LocationGeocoding {
    // actor tự động conform Sendable ✅
    // Vì actor đã bảo vệ internal state → an toàn khi chia sẻ
```

Nếu đây là `class` thường → phải tự chứng minh `Sendable` (thường không thể nếu có mutable state).

### Method phân tích

```swift
func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
    // 1. Tạo geocoder MỚI cho mỗi request
    let geocoder = CLGeocoder()
    
    // 2. Tạo CLLocation từ coordinate
    let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    
    // 3. Gọi Apple API — await suspend tại đây
    let places = try await geocoder.reverseGeocodeLocation(location)
    
    // 4. Lấy kết quả đầu tiên hoặc throw
    guard let p = places.first else { throw GeocodeError.noResults }
    
    // 5. Format thành "City, State"
    return [p.locality, p.administrativeArea]
        .compactMap { $0 }                      // bỏ nil
        .joined(separator: ", ")                // "Hanoi, Hanoi"
}
```

### Tại sao tạo `CLGeocoder()` mới mỗi lần?

Comment trong code giải thích: `CLGeocoder` instance **không thể xử lý đồng thời nhiều request**. Nếu dùng shared instance:

```swift
// ❌ Shared CLGeocoder
actor BadGeocoder {
    private let geocoder = CLGeocoder()    // 1 instance dùng chung
    
    func reverse(_ coord: ...) async throws -> String {
        // Request A gọi geocoder.reverseGeocodeLocation(...)
        // Request B cũng gọi → Apple cancel Request A ← BUG
        return try await geocoder.reverseGeocodeLocation(...)
    }
}
```

Nhờ actor serialization, hai request **không chạy đồng thời** bên trong actor. Nhưng khi gặp `await`, actor nhả lock → request B có thể bắt đầu trước khi A xong → CLGeocoder cancel request A.

Giải pháp: **tạo instance mới** cho mỗi request → mỗi request có geocoder riêng → không ảnh hưởng nhau:

```swift
// ✅ Request-scoped geocoder
func reverseGeocode(_ coord: ...) async throws -> String {
    let geocoder = CLGeocoder()  // local → mỗi request riêng biệt
    // Dù actor nhả lock tại await, geocoder này chỉ thuộc về task hiện tại
    return try await geocoder.reverseGeocodeLocation(...)
}
```

---

## 5. Actor vs alternatives

### Khi nào dùng actor?

```
Mutable shared state + concurrent access?
    │
    ├── Không có mutable state        → struct / class thường ✅
    │
    ├── Có, nhưng chỉ trên Main Thread → @MainActor ✅
    │
    ├── Có, đa luồng, logic đơn giản  → actor ✅
    │
    └── Có, đa luồng, cần kế thừa     → class + manual synchronization
                                         (actor không hỗ trợ inheritance)
```

### `@MainActor` — Actor đặc biệt cho UI

```swift
// @MainActor = actor chạy trên Main Thread
// Dùng cho ViewModel vì UI update phải trên main
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var name = ""          // ghi trên main → an toàn cho UI
    @Published var isLoading = false
    
    func loadProfile() async {
        isLoading = true              // main thread ✅
        let profile = try? await api.fetchProfile()  // await → suspend, nhả main
        name = profile?.name ?? ""    // quay lại main thread ✅
        isLoading = false
    }
}
```

So sánh:

```
actor                          @MainActor class
─────                          ────────────────
Serial executor riêng          Serial executor = Main Thread
Chạy trên background thread    Chạy trên Main Thread
Dùng cho data layer,           Dùng cho ViewModel, UI logic
network cache, geocoding
```

---

## 6. Ví dụ mở rộng — Actor với cache

```swift
actor GeocodingService: LocationGeocoding {
    // Mutable state — actor bảo vệ tự động
    private var cache: [String: String] = [:]
    private var inFlightRequests: [String: Task<String, Error>] = [:]
    
    func reverseGeocode(_ coord: CLLocationCoordinate2D) async throws -> String {
        let key = "\(coord.latitude),\(coord.longitude)"
        
        // 1. Check cache (trong actor, truy cập trực tiếp)
        if let cached = cache[key] {
            return cached
        }
        
        // 2. Check in-flight (tránh duplicate request)
        if let existing = inFlightRequests[key] {
            return try await existing.value  // chờ request đang chạy
        }
        
        // 3. Tạo request mới
        let task = Task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let places = try await geocoder.reverseGeocodeLocation(location)
            guard let p = places.first else { throw GeocodeError.noResults }
            return [p.locality, p.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")
        }
        
        inFlightRequests[key] = task  // ghi state — an toàn trong actor
        
        do {
            let result = try await task.value
            // ⚠️ Sau await, state có thể đã thay đổi — nhưng logic vẫn đúng
            cache[key] = result
            inFlightRequests[key] = nil
            return result
        } catch {
            inFlightRequests[key] = nil
            throw error
        }
    }
    
    // Method để clear cache — cũng được bảo vệ
    func clearCache() {
        cache.removeAll()
    }
}
```

### Sử dụng trong SwiftUI ViewModel

```swift
@MainActor
class MapViewModel: ObservableObject {
    @Published var address = ""
    @Published var isGeocoding = false
    
    private let geocoder: LocationGeocoding  // protocol, không biết concrete type
    
    init(geocoder: LocationGeocoding = CoreLocationGeocoder()) {
        self.geocoder = geocoder
    }
    
    func lookupAddress(for coordinate: CLLocationCoordinate2D) async {
        isGeocoding = true
        defer { isGeocoding = false }
        
        do {
            // Cross-actor call: MainActor → CoreLocationGeocoder actor
            // Tự động await, compiler enforce
            address = try await geocoder.reverseGeocode(coordinate)
        } catch {
            address = "Unknown location"
        }
    }
}
```

```
┌────────────────────────┐          ┌──────────────────────────┐
│ @MainActor             │          │ actor CoreLocationGeocoder│
│ MapViewModel           │          │                          │
│                        │  await   │                          │
│ lookupAddress() ───────────────▶  │ reverseGeocode()         │
│   suspend on main      │          │   runs on actor executor │
│   ...                  │  return  │   serial access to cache │
│   resume ◀─────────────────────── │                          │
│   address = result     │          │                          │
│   (main thread ✅)     │          │                          │
└────────────────────────┘          └──────────────────────────┘
```

---

## 7. `nonisolated` — Thoát khỏi actor isolation

Một số method **không truy cập mutable state** → không cần serialization → đánh dấu `nonisolated` để gọi mà không cần `await`:

```swift
actor CoreLocationGeocoder: LocationGeocoding {
    private var cache: [String: String] = [:]
    
    func reverseGeocode(...) async throws -> String {
        // isolated — cần await từ bên ngoài
    }
    
    // Không truy cập mutable state → nonisolated
    nonisolated func supportedRegions() -> [String] {
        return ["VN", "US", "JP", "KR"]  // constant data, không cần bảo vệ
    }
    
    // nonisolated cho computed property
    nonisolated var description: String {
        "CoreLocationGeocoder"  // không đọc cache hay mutable state
    }
}

// Gọi nonisolated — KHÔNG cần await
let geocoder = CoreLocationGeocoder()
let regions = geocoder.supportedRegions()    // đồng bộ, không await
```

---

## 8. Tóm tắt

| Khái niệm | Ý nghĩa |
|---|---|
| `actor` | Reference type có **serial executor** nội bộ — tự động serialize mọi access vào mutable state, loại bỏ data race |
| Cross-actor call | Gọi method từ bên ngoài → bắt buộc `await` (suspend cho đến khi actor sẵn sàng) |
| Internal access | Bên trong actor → truy cập trực tiếp, không cần await |
| Re-entrancy | Tại mỗi `await` bên trong actor, actor nhả lock → state có thể thay đổi khi quay lại |
| `Sendable` tự động | Actor tự conform `Sendable` — an toàn truyền giữa concurrency domains |
| `nonisolated` | Đánh dấu method/property không cần isolation — gọi đồng bộ từ bên ngoài |
| `@MainActor` | Actor đặc biệt chạy trên Main Thread — dùng cho ViewModel, UI logic |

------------

`actor` giải quyết bài toán **data race** một cách tự động ở tầng ngôn ngữ, Huy. Trước đây phải tự quản lý `DispatchQueue`, lock, semaphore — giờ compiler enforce tất cả.

Cốt lõi: actor là reference type (như class) nhưng có **serial executor** nội bộ. Mọi truy cập từ bên ngoài bắt buộc `await` — Task suspend cho đến khi actor sẵn sàng. Bên trong actor, truy cập mutable state trực tiếp mà không cần đồng bộ thủ công.

Trong đoạn code, có hai chi tiết đáng chú ý:

**`Sendable` trên protocol** — đảm bảo object implement protocol này an toàn khi truyền giữa các concurrency domain (Task, actor khác). Actor tự động conform `Sendable` nên `CoreLocationGeocoder` thoả mãn ngay.

**Tạo `CLGeocoder()` mới mỗi request** — đây là do actor re-entrancy. Khi gặp `await geocoder.reverseGeocodeLocation(...)`, actor nhả lock → request khác có thể bắt đầu. Nếu dùng chung một `CLGeocoder` instance, Apple sẽ cancel request đang chạy. Tạo instance mới cho mỗi request giải quyết triệt để vấn đề này.
