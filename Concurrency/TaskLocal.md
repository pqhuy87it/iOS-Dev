# TaskLocal trong Swift Concurrency

`TaskLocal` là một cơ chế **implicit data propagation** — cho phép bạn gắn metadata vào một Task và tự động truyền xuống toàn bộ child tasks mà **không cần truyền qua parameter**.

Hãy nghĩ nó như **"biến môi trường" cho Task tree**, tương tự concept `Environment` trong SwiftUI nhưng dành cho concurrency context.

---

## 1. Cú pháp cơ bản

```swift
enum MyTaskLocals {
    @TaskLocal static var requestID: String?
    @TaskLocal static var logLevel: LogLevel = .info  // Có default value
}
```

**Rules:**
- Phải là `static` property
- Chỉ có thể **đọc** ở bất kỳ đâu trong task tree
- Chỉ có thể **gán** thông qua `$property.withValue(_:operation:)` — không dùng `=`

```swift
// ❌ Compile error — không thể gán trực tiếp
MyTaskLocals.$requestID = "abc-123"

// ✅ Binding qua withValue
MyTaskLocals.$requestID.withValue("abc-123") {
    print(MyTaskLocals.requestID) // "abc-123"
    
    // Mọi child task trong scope này đều thấy giá trị
    Task {
        print(MyTaskLocals.requestID) // "abc-123" — inherited!
    }
}

print(MyTaskLocals.requestID) // nil — ra khỏi scope, về default
```

---

## 2. Propagation Rules — Cách giá trị lan truyền

Đây là phần quan trọng nhất để hiểu `TaskLocal`:

```swift
@TaskLocal static var traceID: String = "none"

func demonstratePropagation() async {
    print("1. Root: \(traceID)") // "none" (default)
    
    await Self.$traceID.withValue("trace-A") {
        print("2. Scope A: \(traceID)") // "trace-A"
        
        // ✅ Structured child task — INHERITS parent's TaskLocal
        async let childResult = fetchData()
        // Bên trong fetchData(), traceID == "trace-A"
        
        // ✅ Task { } (unstructured nhưng inherit actor) — INHERITS
        Task {
            print("3. Task {}: \(traceID)") // "trace-A"
        }
        
        // ❌ Task.detached — KHÔNG INHERIT
        Task.detached {
            print("4. Detached: \(traceID)") // "none" (reset về default!)
        }
        
        // ✅ TaskGroup — INHERITS
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                print("5. TaskGroup child: \(traceID)") // "trace-A"
            }
        }
        
        // ✅ Nested withValue — override cho inner scope
        await Self.$traceID.withValue("trace-B") {
            print("6. Inner scope: \(traceID)") // "trace-B"
            
            Task {
                print("7. Inner Task: \(traceID)") // "trace-B"
            }
        }
        
        print("8. Back to outer: \(traceID)") // "trace-A" — restored
        
        _ = await childResult
    }
    
    print("9. Outside: \(traceID)") // "none" — restored
}
```

### Bảng tóm tắt propagation

| Loại Task | Inherit TaskLocal? | Giải thích |
|---|---|---|
| `async let` | ✅ Có | Structured child — luôn inherit |
| `TaskGroup.addTask` | ✅ Có | Structured child |
| `Task { }` | ✅ Có | Unstructured nhưng inherit current context |
| `Task.detached { }` | ❌ Không | Hoàn toàn tách rời, reset về default |
| `withValue` lồng nhau | ✅ Override | Inner scope override, outer scope được restore |

---

## 3. Use Case thực tế: Distributed Tracing / Request Context

Đây là use case **kinh điển** và mạnh nhất của `TaskLocal`:

```swift
// MARK: - Định nghĩa TaskLocal cho request context

enum RequestContext {
    @TaskLocal static var requestID: String = "no-request"
    @TaskLocal static var userID: String?
    @TaskLocal static var correlationID: String = UUID().uuidString
}

// MARK: - Logger tự động attach context

struct ContextualLogger {
    static func log(_ message: String, level: LogLevel = .info) {
        let entry = """
        [\(level)] [req:\(RequestContext.requestID)] \
        [user:\(RequestContext.userID ?? "anonymous")] \
        [corr:\(RequestContext.correlationID)] \
        \(message)
        """
        print(entry)
    }
}

// MARK: - Service layers — KHÔNG CẦN truyền requestID qua parameter

class OrderService {
    func createOrder(items: [CartItem]) async throws -> Order {
        // Logger tự động biết requestID mà không cần parameter
        ContextualLogger.log("Creating order with \(items.count) items")
        
        let order = try await OrderRepository.save(items: items)
        
        // Gọi tiếp sang PaymentService — requestID vẫn tự propagate
        try await PaymentService().charge(order: order)
        
        ContextualLogger.log("Order \(order.id) created successfully")
        return order
    }
}

class PaymentService {
    func charge(order: Order) async throws {
        // Vẫn thấy cùng requestID — zero parameter passing!
        ContextualLogger.log("Charging \(order.total) for order \(order.id)")
        
        async let payment = PaymentGateway.process(order.total)
        async let receipt = ReceiptGenerator.generate(order)
        
        // Cả 2 child tasks đều inherit requestID
        let (paymentResult, receiptData) = await (try payment, try receipt)
        
        ContextualLogger.log("Payment completed: \(paymentResult.transactionID)")
    }
}

// MARK: - Entry point — bind value tại đây

struct APIHandler {
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let requestID = UUID().uuidString
        
        return try await RequestContext.$requestID.withValue(requestID) {
            await RequestContext.$userID.withValue(request.authenticatedUserID) {
                ContextualLogger.log("Request started: \(request.path)")
                
                let result = try await routeRequest(request)
                
                ContextualLogger.log("Request completed")
                return result
            }
        }
    }
}
```

**Tại sao pattern này mạnh?** So sánh với cách truyền thống:

```swift
// ❌ Phải truyền requestID qua TỪNG layer — parameter drilling hell
func createOrder(items: [CartItem], requestID: String, userID: String?) async throws -> Order
func charge(order: Order, requestID: String, userID: String?) async throws
func process(amount: Decimal, requestID: String) async throws -> PaymentResult
func generate(order: Order, requestID: String) async throws -> Receipt

// ✅ Với TaskLocal — clean function signatures
func createOrder(items: [CartItem]) async throws -> Order
func charge(order: Order) async throws
func process(amount: Decimal) async throws -> PaymentResult
func generate(order: Order) async throws -> Receipt
```

---

## 4. Use Case: Performance Instrumentation

```swift
enum Instrumentation {
    @TaskLocal static var spanName: String = "root"
    @TaskLocal static var spanStartTime: ContinuousClock.Instant?
}

struct Tracer {
    /// Wrap một operation trong một "span" để đo performance
    static func span<T>(
        _ name: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = ContinuousClock.now
        
        let result = try await Instrumentation.$spanName.withValue(name) {
            try await Instrumentation.$spanStartTime.withValue(start) {
                try await operation()
            }
        }
        
        let duration = ContinuousClock.now - start
        print("⏱ [\(Instrumentation.spanName)] \(name): \(duration)")
        
        return result
    }
}

// Sử dụng
func loadDashboard() async throws -> Dashboard {
    try await Tracer.span("loadDashboard") {
        async let profile = Tracer.span("fetchProfile") {
            try await api.fetchProfile()
        }
        async let stats = Tracer.span("fetchStats") {
            try await api.fetchStats()
        }
        async let feed = Tracer.span("fetchFeed") {
            try await api.fetchFeed()
        }
        
        return try await Dashboard(
            profile: profile,
            stats: stats,
            feed: feed
        )
    }
}

// Output:
// ⏱ [loadDashboard] fetchProfile: 0.234 seconds
// ⏱ [loadDashboard] fetchStats: 0.189 seconds
// ⏱ [loadDashboard] fetchFeed: 0.312 seconds
// ⏱ [root] loadDashboard: 0.315 seconds  ← parallel nên ≈ max(children)
```

---

## 5. Use Case trong SwiftUI: Feature Flags / A/B Testing

```swift
enum FeatureFlags {
    @TaskLocal static var isNewUIEnabled: Bool = false
    @TaskLocal static var experimentGroup: String = "control"
}

// Middleware bind flags từ remote config
@MainActor
struct ContentView: View {
    @State private var flags: RemoteFlags?
    
    var body: some View {
        MainTabView()
            .task {
                flags = await RemoteConfigService.fetchFlags()
                
                // Bind flags cho toàn bộ async work
                await FeatureFlags.$isNewUIEnabled.withValue(flags?.newUI ?? false) {
                    await FeatureFlags.$experimentGroup.withValue(flags?.group ?? "control") {
                        await startBackgroundSync()
                    }
                }
            }
    }
    
    private func startBackgroundSync() async {
        // Analytics tự động biết experiment group
        AnalyticsService.log("sync_started", 
            group: FeatureFlags.experimentGroup) // Không cần parameter!
        
        // Logic branch theo feature flag
        if FeatureFlags.isNewUIEnabled {
            await NewSyncEngine.sync()
        } else {
            await LegacySyncEngine.sync()
        }
    }
}
```

---

## 6. Kết hợp TaskLocal với Actor

```swift
actor DatabaseActor {
    @TaskLocal static var transactionID: String?
    
    private var connections: [String: DBConnection] = [:]
    
    func execute(_ query: String) async throws -> [Row] {
        let txID = Self.transactionID ?? "auto-\(UUID().uuidString.prefix(8))"
        print("[\(txID)] Executing: \(query)")
        
        // Nếu đang trong transaction, reuse connection
        if let txID = Self.transactionID, let conn = connections[txID] {
            return try await conn.execute(query)
        }
        
        return try await pool.acquire().execute(query)
    }
    
    func withTransaction<T>(_ operation: () async throws -> T) async throws -> T {
        let txID = UUID().uuidString
        let conn = try await pool.acquire()
        connections[txID] = conn
        
        defer {
            connections.removeValue(forKey: txID)
            conn.release()
        }
        
        try await conn.execute("BEGIN")
        
        do {
            // Mọi query trong operation sẽ thấy cùng transactionID
            let result = try await Self.$transactionID.withValue(txID) {
                try await operation()
            }
            try await conn.execute("COMMIT")
            return result
        } catch {
            try await conn.execute("ROLLBACK")
            throw error
        }
    }
}

// Sử dụng
let db = DatabaseActor()

try await db.withTransaction {
    try await db.execute("INSERT INTO orders ...")
    try await db.execute("UPDATE inventory ...")  // Cùng transaction!
    try await db.execute("INSERT INTO audit_log ...")
}
```

---

## 7. Lưu ý quan trọng và Pitfalls

### 7.1. `withValue` là synchronous closure nếu không có `await`

```swift
// ✅ Async version — đúng khi cần await bên trong
await Self.$traceID.withValue("abc") {
    await someAsyncWork()
}

// ✅ Sync version — dùng khi chỉ cần scope binding
Self.$traceID.withValue("abc") {
    syncWork()  // Không có await
}
```

### 7.2. Không dùng TaskLocal thay thế cho dependency injection

```swift
// ❌ Anti-pattern: Dùng TaskLocal như service locator
@TaskLocal static var apiService: APIService?

// ✅ Dùng cho cross-cutting concerns (logging, tracing, auth context)
@TaskLocal static var requestID: String?
@TaskLocal static var authToken: String?
```

**Nguyên tắc:** TaskLocal phù hợp cho **metadata/context** mà mọi layer cần nhưng không phải business logic dependency. Nếu bạn cần inject service, dùng constructor injection hoặc SwiftUI `Environment`.

### 7.3. Performance — TaskLocal rất nhẹ

TaskLocal được implement dựa trên **task-local storage** ở runtime level, không phải dictionary lookup. Chi phí gần như zero — an toàn để dùng trong hot paths.

### 7.4. Thread safety

`TaskLocal` là **inherently thread-safe** vì:
- Chỉ có thể write qua `withValue` (scoped)
- Read trả về snapshot tại thời điểm task được tạo
- Không có shared mutable state

---

## Tổng kết khi nào nên dùng TaskLocal

| Nên dùng | Không nên dùng |
|---|---|
| Request ID / Trace ID / Correlation ID | Business logic dependencies |
| Logging context (user, session) | Service/Repository injection |
| Feature flags / A/B test group | UI state |
| Auth token propagation | Mutable shared state (dùng Actor) |
| Performance instrumentation spans | Anything cần giao tiếp giữa unrelated tasks |
| Transaction context | Data flow chính của app |

**Tóm lại:** `TaskLocal` giải quyết bài toán **"cross-cutting concern propagation"** — khi bạn có metadata cần đi theo call chain nhưng không muốn ô nhiễm function signatures. Nó là missing piece giữa "truyền qua parameter" (quá verbose) và "global variable" (không thread-safe, không scoped).

Cần mình đi sâu thêm phần nào không, ví dụ cách Swift runtime implement TaskLocal hay so sánh với `ThreadLocal` truyền thống?
