# Swift Concurrency vs Combine — So sánh chi tiết

## 1. Bản chất và Triết lý thiết kế

### Swift Concurrency

Swift Concurrency là **language-level feature** — được tích hợp trực tiếp vào ngôn ngữ Swift, với syntax riêng (`async`, `await`, `actor`), compiler enforcement, và runtime riêng (cooperative thread pool).

Triết lý: **Làm cho asynchronous code trông giống synchronous code** — dễ đọc, dễ hiểu, dễ debug.

```swift
// Đọc từ trên xuống dưới như synchronous code
func loadUserProfile() async throws -> Profile {
    let user = try await api.fetchUser()
    let avatar = try await api.fetchAvatar(userId: user.id)
    let preferences = try await api.fetchPreferences(userId: user.id)
    return Profile(user: user, avatar: avatar, preferences: preferences)
}
```

### Combine

Combine là **framework** — một reactive programming framework của Apple, lấy cảm hứng từ ReactiveX/RxSwift. Nó mô hình hóa mọi thứ thành **streams of values over time** (Publisher → Operator → Subscriber).

Triết lý: **Mọi thứ đều là stream** — data flow là chuỗi biến đổi (transformation pipeline) trên dòng dữ liệu.

```swift
// Pipeline: Publisher → transform → transform → subscribe
api.fetchUserPublisher()
    .flatMap { user in api.fetchAvatarPublisher(userId: user.id) }
    .map { avatar in Profile(avatar: avatar) }
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { completion in /* handle error */ },
        receiveValue: { profile in /* use profile */ }
    )
    .store(in: &cancellables)
```

---

## 2. Mental Model — Cách tư duy khác nhau

### Swift Concurrency: "Làm việc A, rồi làm việc B"

Bạn tư duy theo **các bước tuần tự**, mỗi bước có thể async nhưng logic vẫn đọc từ trên xuống dưới.

```swift
// Mental model: Tôi làm bước 1, xong làm bước 2, xong làm bước 3
func placeOrder() async throws {
    let cart = try await cartService.getCart()
    let validated = try await paymentService.validate(cart: cart)
    let order = try await orderService.place(validatedCart: validated)
    try await notificationService.sendConfirmation(order: order)
}
```

### Combine: "Data chảy qua một đường ống biến đổi"

Bạn tư duy theo **data pipeline** — data đi vào từ đầu này, chảy qua các operator biến đổi, ra kết quả ở đầu kia.

```swift
// Mental model: Data chảy qua pipeline
//   cart → validate → place order → send notification
cartService.getCartPublisher()
    .flatMap { cart in paymentService.validatePublisher(cart: cart) }
    .flatMap { validated in orderService.placePublisher(validatedCart: validated) }
    .flatMap { order in notificationService.sendConfirmationPublisher(order: order) }
    .receive(on: DispatchQueue.main)
    .sink(receiveCompletion: { ... }, receiveValue: { ... })
    .store(in: &cancellables)
```

---

## 3. Loại công việc phù hợp

### One-shot async operations (API call, file read, database query)

```swift
// ✅ Swift Concurrency — RẤT PHÙ HỢP, clean và simple
func fetchProduct(id: String) async throws -> Product {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw APIError.badResponse
    }
    return try JSONDecoder().decode(Product.self, from: data)
}

// ⚠️ Combine — Hoạt động nhưng verbose hơn nhiều
func fetchProduct(id: String) -> AnyPublisher<Product, Error> {
    URLSession.shared.dataTaskPublisher(for: url)
        .tryMap { data, response in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw APIError.badResponse
            }
            return data
        }
        .decode(type: Product.self, decoder: JSONDecoder())
        .eraseToAnyPublisher()
}
```

**Winner: Swift Concurrency** — ít code hơn, dễ đọc hơn, error handling tự nhiên hơn.

### Continuous streams of values (user input, sensor data, real-time updates)

```swift
// ⚠️ Swift Concurrency — AsyncSequence hoạt động nhưng hạn chế operators
func observeSearchResults() async {
    for await text in searchTextField.textChanges {
        // Không có built-in debounce, throttle, combineLatest...
        // Phải tự implement hoặc dùng thư viện
        let results = try? await api.search(query: text)
        self.results = results ?? []
    }
}

// ✅ Combine — SINH RA ĐỂ LÀM VIỆC NÀY
searchTextField.textPublisher
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates()
    .filter { $0.count >= 2 }
    .flatMap { query in
        api.searchPublisher(query: query)
            .catch { _ in Just([]) }
    }
    .receive(on: DispatchQueue.main)
    .assign(to: &$searchResults)
```

**Winner: Combine** — built-in operators cho stream manipulation rất mạnh.

### Multiple concurrent operations

```swift
// ✅ Swift Concurrency — Built-in, elegant
func loadDashboard() async throws -> Dashboard {
    async let sales = api.fetchSales()
    async let inventory = api.fetchInventory()
    async let analytics = api.fetchAnalytics()
    
    return Dashboard(
        sales: try await sales,
        inventory: try await inventory,
        analytics: try await analytics
    )
}

// ⚠️ Combine — Hoạt động nhưng Zip có giới hạn
// Zip chỉ support tối đa Zip4 (4 publishers)
// Nhiều hơn phải nest → khó đọc
Publishers.Zip3(
    api.fetchSalesPublisher(),
    api.fetchInventoryPublisher(),
    api.fetchAnalyticsPublisher()
)
.sink { sales, inventory, analytics in
    self.dashboard = Dashboard(sales: sales, inventory: inventory, analytics: analytics)
}
.store(in: &cancellables)

// Nếu cần 10 concurrent calls:
// Combine: phải nest Zip hoặc dùng MergeMany
// Swift Concurrency: TaskGroup — đơn giản, clean
```

**Winner: Swift Concurrency** — TaskGroup scale tự nhiên với bất kỳ số lượng tasks nào.

---

## 4. Error Handling

### Swift Concurrency

```swift
// Error handling giống hệt synchronous code — try/catch
func loadProfile() async {
    do {
        let user = try await api.fetchUser()
        
        // Có thể catch granular từng bước
        let avatar: UIImage
        do {
            avatar = try await api.fetchAvatar(userId: user.id)
        } catch {
            avatar = UIImage(named: "default_avatar")!  // Fallback
        }
        
        self.profile = Profile(user: user, avatar: avatar)
    } catch is URLError {
        self.error = .network
    } catch is DecodingError {
        self.error = .parsing
    } catch {
        self.error = .unknown(error)
    }
}
```

**Đặc điểm:**

- Dùng `do/catch` quen thuộc — mọi Swift developer đã biết
- Có thể catch từng bước riêng lẻ
- Error type rõ ràng, pattern matching dễ dàng
- Đọc từ trên xuống — logic flow rõ ràng

### Combine

```swift
// Error handling thông qua Completion và operators
api.fetchUserPublisher()
    .flatMap { user in
        api.fetchAvatarPublisher(userId: user.id)
            .catch { _ in
                // Catch trong flatMap — fallback cho avatar
                Just(UIImage(named: "default_avatar")!)
                    .setFailureType(to: Error.self)
            }
            .map { avatar in Profile(user: user, avatar: avatar) }
    }
    .mapError { error -> AppError in
        // Transform error type
        if error is URLError { return .network }
        if error is DecodingError { return .parsing }
        return .unknown(error)
    }
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                self.error = error
            }
        },
        receiveValue: { profile in
            self.profile = profile
        }
    )
    .store(in: &cancellables)
```

**Đặc điểm:**

- Error là generic type trên Publisher: `Publisher<Output, Failure>`
- `catch`, `mapError`, `replaceError`, `retry` — operators chuyên dụng
- Error type phải match giữa các operator → đôi khi cần `setFailureType`, `mapError` để "adapt" → verbose
- Khi chain dài, error flow khó trace — error có thể bị transform qua nhiều tầng

### So sánh trực tiếp cùng một bài toán: Retry with exponential backoff

```swift
// Swift Concurrency
func fetchWithRetry<T>(maxAttempts: Int = 3, 
                        operation: () async throws -> T) async throws -> T {
    var lastError: Error?
    
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
            try await Task.sleep(nanoseconds: delay)
            // attempt 0: đợi 1s, attempt 1: đợi 2s, attempt 2: đợi 4s
        }
    }
    
    throw lastError!
}

// Sử dụng
let profile = try await fetchWithRetry {
    try await api.fetchProfile()
}
```

```swift
// Combine
api.fetchProfilePublisher()
    .retry(3)  // Retry ngay lập tức — không có delay
    // Muốn exponential backoff phải custom:
    .tryCatch { error -> AnyPublisher<Profile, Error> in
        // Phức tạp hơn nhiều...
        api.fetchProfilePublisher()
            .delay(for: .seconds(pow(2, Double(attempt))), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    .eraseToAnyPublisher()
    // Thực tế rất khó track "attempt" trong Combine chain
    // vì operators là stateless
```

**Winner: Swift Concurrency** — error handling trực quan, dễ custom, dễ debug.

---

## 5. Cancellation

### Swift Concurrency

```swift
class SearchViewModel: ObservableObject {
    private var searchTask: Task<Void, Never>?
    
    func search(query: String) {
        // Cancel task cũ trước khi tạo task mới
        searchTask?.cancel()
        
        searchTask = Task {
            // Kiểm tra cancellation
            try? await Task.sleep(nanoseconds: 300_000_000)  // debounce 300ms
            
            // Task.sleep tự throw CancellationError nếu task bị cancel
            // → code dưới đây KHÔNG chạy nếu user gõ tiếp
            
            guard !Task.isCancelled else { return }  // Check thủ công nếu cần
            
            let results = try? await api.search(query: query)
            
            if !Task.isCancelled {
                self.results = results ?? []
            }
        }
    }
}
```

**Đặc điểm:**

- **Cooperative cancellation** — cancel chỉ set flag, task tự kiểm tra
- `Task.sleep`, `URLSession.data(for:)` tự động check cancellation
- Structured concurrency: child tasks tự động cancel khi parent cancel

```swift
// Structured cancellation — cancel parent → tất cả children cancel
func loadDashboard() async throws {
    // Nếu Task chứa function này bị cancel:
    // → cả 3 async let đều tự động cancel
    async let a = api.fetchA()  // ← auto cancelled
    async let b = api.fetchB()  // ← auto cancelled
    async let c = api.fetchC()  // ← auto cancelled
    
    return try await (a, b, c)
}
```

### Combine

```swift
class SearchViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    func setupSearch(textPublisher: AnyPublisher<String, Never>) {
        textPublisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap(maxPublishers: .max(1)) { query in
                // maxPublishers: .max(1) → cancel publisher trước
                // khi publisher mới emit
                self.api.searchPublisher(query: query)
                    .catch { _ in Just([]) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$results)
    }
    
    deinit {
        // cancellables tự cancel khi ViewModel bị dealloc
        // Nhưng phải NHỚ store vào cancellables, 
        // nếu quên → subscription bị release ngay → không hoạt động
    }
}
```

**Đặc điểm:**

- `AnyCancellable` — cancel khi object dealloc hoặc gọi `.cancel()`
- **Phải tự quản lý lifetime** — quên `store(in: &cancellables)` là bug rất phổ biến
- `switchToLatest` / `flatMap(maxPublishers: .max(1))` để cancel operation cũ

### So sánh cancellation pattern

```swift
// Vấn đề: User mở screen → start loading → navigate away → cancel loading

// Swift Concurrency + SwiftUI
struct ProductDetailView: View {
    var body: some View {
        VStack { ... }
        .task {
            // .task tự động:
            // 1. Tạo Task khi view appear
            // 2. Cancel Task khi view disappear
            // → Không cần quản lý gì thêm
            await viewModel.loadProduct()
        }
    }
}

// Combine + UIKit
class ProductDetailVC: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        viewModel.loadProduct()
            .sink(...)
            .store(in: &cancellables)
        // cancellables sẽ cancel khi VC dealloc
        // NHƯNG: nếu VC nằm trong navigation stack,
        // nó có thể KHÔNG dealloc ngay khi pop
        // → cần cancel thủ công trong viewDidDisappear
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancellables.removeAll()  // Phải tự cancel
    }
}
```

**Winner: Swift Concurrency** — structured cancellation tự động và an toàn hơn.

---

## 6. Thread Safety

### Swift Concurrency: Actor — Compiler enforced

```swift
actor ShoppingCart {
    private var items: [CartItem] = []
    
    func add(item: CartItem) {
        items.append(item)
    }
    
    func remove(itemId: String) {
        items.removeAll { $0.id == itemId }
    }
    
    var total: Double {
        items.reduce(0) { $0 + $1.price * Double($0.quantity) }
    }
    
    var itemCount: Int { items.count }
}

// Truy cập từ bên ngoài — COMPILER BẮT BUỘC dùng await
let cart = ShoppingCart()
await cart.add(item: newItem)      // ✅
let count = await cart.itemCount   // ✅
// cart.items.append(item)         // ❌ Compiler error — không truy cập trực tiếp được

// Sendable protocol — compiler kiểm tra data có safe để gửi giữa actors không
struct CartItem: Sendable {  // Tất cả properties phải immutable hoặc Sendable
    let id: String
    let name: String
    let price: Double
    let quantity: Int
}
```

**Compiler đảm bảo:**

- Không thể truy cập actor state mà không `await`
- `Sendable` checking — data truyền giữa actor boundaries phải thread-safe
- Data race detected tại **compile time**, không phải runtime

### Combine: Tự quản lý

```swift
class ShoppingCart {
    // Combine không có built-in thread safety mechanism
    // Bạn phải tự protect shared state
    
    // Cách 1: Dùng serial queue
    private let queue = DispatchQueue(label: "cart.queue")
    private var items: [CartItem] = []
    
    @Published var itemCount: Int = 0  // @Published KHÔNG thread-safe!
    
    func add(item: CartItem) {
        queue.async { [weak self] in
            self?.items.append(item)
            DispatchQueue.main.async {
                self?.itemCount = self?.items.count ?? 0
            }
        }
    }
    
    // Cách 2: Dùng CurrentValueSubject thay cho @Published
    private let itemsSubject = CurrentValueSubject<[CartItem], Never>([])
    
    // Nhưng CurrentValueSubject cũng KHÔNG thread-safe khi send từ nhiều threads!
    // Phải protect bằng lock hoặc serial queue
}
```

**Combine không có built-in thread safety.** Bạn phải:

- Tự dùng lock, serial queue, hoặc barrier
- Biết rằng `@Published` không thread-safe
- Biết rằng `CurrentValueSubject.send()` từ nhiều threads cùng lúc có thể crash
- Không có compiler check — race condition chỉ phát hiện khi chạy

**Winner: Swift Concurrency** — compiler-enforced safety vs tự kỷ luật.

---

## 7. Operators / Transformation Capabilities

Đây là nơi Combine **vượt trội**.

### Combine: Hệ sinh thái operators cực kỳ phong phú

```swift
// Debounce — đợi user ngừng gõ mới execute
textPublisher
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)

// Throttle — chỉ lấy value đầu tiên trong mỗi khoảng thời gian
locationPublisher
    .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: true)

// CombineLatest — kết hợp giá trị mới nhất từ nhiều streams
Publishers.CombineLatest3(usernamePublisher, emailPublisher, passwordPublisher)
    .map { username, email, password in
        !username.isEmpty && email.contains("@") && password.count >= 8
    }
    .assign(to: &$isFormValid)

// Scan — accumulate giá trị (giống reduce nhưng emit mỗi bước)
eventPublisher
    .scan(0) { count, _ in count + 1 }
    // emit: 1, 2, 3, 4, 5, ...

// SwitchToLatest — cancel publisher cũ khi có publisher mới
searchTextPublisher
    .map { query in api.searchPublisher(query: query) }
    .switchToLatest()  // Chỉ giữ kết quả search mới nhất

// Merge — gộp nhiều streams thành một
Publishers.Merge3(
    bluetoothEvents,
    networkEvents, 
    userInputEvents
)

// Zip — đợi TẤT CẢ emit rồi mới combine
Publishers.Zip(publisherA, publisherB)
// A emit 1, B chưa emit → đợi
// B emit "x" → emit (1, "x")

// Buffer — gom nhiều values thành batch
sensorDataPublisher
    .collect(.byTime(RunLoop.main, .seconds(1)))
    // Thu thập tất cả values trong 1 giây, emit 1 array

// Retry with delay
api.fetchPublisher()
    .delay(for: .seconds(2), scheduler: DispatchQueue.global())
    .retry(3)
```

### Swift Concurrency: AsyncSequence — Hạn chế hơn nhiều

```swift
// AsyncSequence có một số operators cơ bản (iOS 15+)
let results = url.lines
    .filter { !$0.isEmpty }
    .map { line in parse(line) }
    .prefix(100)

// KHÔNG có built-in:
// ❌ debounce
// ❌ throttle
// ❌ combineLatest
// ❌ switchToLatest
// ❌ scan
// ❌ buffer
// ❌ merge (có trong iOS 17+ nhưng hạn chế)
```

Để có các operators tương đương trong Swift Concurrency, bạn phải tự implement hoặc dùng thư viện **swift-async-algorithms** (của Apple):

```swift
// swift-async-algorithms (package riêng, không built-in)
import AsyncAlgorithms

// Debounce
for await text in searchText.debounce(for: .milliseconds(300)) {
    let results = try await api.search(query: text)
}

// CombineLatest
for await (username, email, password) in combineLatest(
    usernameStream, emailStream, passwordStream
) {
    isFormValid = !username.isEmpty && email.contains("@") && password.count >= 8
}

// Merge
for await event in merge(bluetoothEvents, networkEvents) {
    handle(event)
}

// Throttle
for await location in locationStream.throttle(for: .seconds(1)) {
    updateMap(location)
}
```

**Winner: Combine** — mature, đầy đủ operators built-in. Swift Concurrency đang bắt kịp nhưng vẫn cần package bổ sung.

---

## 8. Debugging Experience

### Swift Concurrency

```swift
func loadProfile() async throws -> Profile {
    let user = try await api.fetchUser()        // Breakpoint ở đây ✅
    let avatar = try await api.fetchAvatar(user.id)  // Step over đến đây ✅
    return Profile(user: user, avatar: avatar)   // Step over đến đây ✅
}
// Stack trace rõ ràng, đọc từ trên xuống
// Xcode hiển thị Task hierarchy trong Debug Navigator
```

**Debugging tools:**

- **Breakpoints** hoạt động bình thường — step over qua `await` points
- **Stack trace** hiển thị async call chain rõ ràng
- **Swift Concurrency Instrument** — visualize task creation, suspension, resumption
- **TSAN (Thread Sanitizer)** phát hiện data races
- Xcode Debug Navigator hiển thị **Task tree**

### Combine

```swift
api.fetchUserPublisher()
    .flatMap { user in api.fetchAvatarPublisher(userId: user.id) }
    .map { avatar in Profile(avatar: avatar) }
    .receive(on: DispatchQueue.main)
    .sink(receiveCompletion: { ... }, receiveValue: { ... })
    .store(in: &cancellables)

// Breakpoint ở đâu? 
// → Phải đặt breakpoint TRONG closure của mỗi operator
// → Stack trace toàn là internal Combine frames, rất khó đọc
// → Không thấy "flow" từ trên xuống
```

**Debugging issues:**

- Breakpoint trong closure — stack trace toàn Combine internal code
- **"Print debugging"** là cách phổ biến nhất: dùng `.print()` hoặc `.handleEvents()`

```swift
// Cách debug phổ biến trong Combine
api.fetchUserPublisher()
    .print("🔵 fetchUser")  // Print mọi events: subscription, value, completion
    .handleEvents(
        receiveSubscription: { _ in print("subscribed") },
        receiveOutput: { print("got value: \($0)") },
        receiveCompletion: { print("completed: \($0)") },
        receiveCancel: { print("cancelled") }
    )
    .flatMap { ... }
```

- Khi chain dài (10+ operators), rất khó trace **value đi đâu, transform ở đâu, mất ở đâu**
- Error bị "nuốt" nếu operator chain không handle completion properly

**Winner: Swift Concurrency** — debugging experience gần như giống synchronous code.

---

## 9. Learning Curve

### Swift Concurrency

Cần học:

```
Level 1 (Cơ bản):
├── async / await syntax
├── Task { }
├── try await
└── @MainActor

Level 2 (Intermediate):
├── async let (structured concurrency)
├── TaskGroup
├── Task cancellation
└── AsyncSequence basics

Level 3 (Advanced):
├── Actor và actor isolation
├── Sendable protocol
├── GlobalActor
├── AsyncStream / AsyncThrowingStream
├── Continuation (bridging callback → async)
└── Task local values
```

Điểm thuận lợi: syntax gần giống synchronous code → developer quen thuộc nhanh. Error handling dùng try/catch quen thuộc.

### Combine

Cần học:

```
Level 1 (Cơ bản):
├── Publisher / Subscriber concept
├── sink / assign
├── AnyCancellable & memory management
└── @Published

Level 2 (Intermediate):
├── 30+ operators (map, flatMap, filter, merge, zip, combineLatest...)
├── Scheduler concept
├── Error types và type erasing (eraseToAnyPublisher)
├── Subject (PassthroughSubject, CurrentValueSubject)
└── Backpressure (Demand)

Level 3 (Advanced):
├── Custom Publisher
├── Custom Subscriber
├── Custom Subscription (Backpressure handling)
├── Operator composition
├── Publisher debugging
└── Combine + UIKit integration patterns
```

**Combine learning curve dốc hơn nhiều** vì:

1. **Paradigm shift** — phải chuyển từ imperative sang reactive thinking
2. **Operator explosion** — 100+ operators, phải biết khi nào dùng cái nào
3. **Type system phức tạp** — generic types nested sâu

```swift
// Kiểu thực tế của một Combine chain — nhìn đã sợ
Publishers.FlatMap
    Publishers.MapError
        Publishers.Map
            URLSession.DataTaskPublisher,
            Data
        >,
        AppError
    >,
    Publishers.Filter
        Publishers.Debounce
            Published<String>.Publisher,
            RunLoop
        >
    >
>
// → Đây là lý do eraseToAnyPublisher() tồn tại
// Nhưng erase lại mất type information → khó debug
```

4. **Memory management traps** — quên `store(in:)`, retain cycle trong closures

**Winner: Swift Concurrency** — dễ học hơn, ít "gotcha" hơn.

---

## 10. Integration với SwiftUI

### Swift Concurrency + SwiftUI

```swift
// Tích hợp cực kỳ tự nhiên
struct ProductListView: View {
    @State private var products: [Product] = []
    @State private var isLoading = false
    
    var body: some View {
        List(products) { product in
            ProductRow(product: product)
        }
        .task {
            // Tự tạo Task khi appear, cancel khi disappear
            isLoading = true
            products = (try? await api.fetchProducts()) ?? []
            isLoading = false
        }
        .refreshable {
            // Pull to refresh — built-in async support
            products = (try? await api.fetchProducts()) ?? []
        }
        .searchable(text: $searchText)
        .task(id: searchText) {
            // Chạy lại mỗi khi searchText thay đổi
            // Tự cancel task cũ → debounce tự nhiên
            try? await Task.sleep(nanoseconds: 300_000_000)
            products = (try? await api.search(query: searchText)) ?? []
        }
    }
}
```

### Combine + SwiftUI

```swift
// Hoạt động tốt nhưng cần boilerplate hơn
class ProductListViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Setup reactive pipeline
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { $0.count >= 2 }
            .flatMap { [weak self] query -> AnyPublisher<[Product], Never> in
                guard let self else { return Just([]).eraseToAnyPublisher() }
                return self.api.searchPublisher(query: query)
                    .catch { _ in Just([]) }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$products)
    }
    
    func loadProducts() {
        isLoading = true
        api.fetchProductsPublisher()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] _ in self?.isLoading = false },
                receiveValue: { [weak self] in self?.products = $0 }
            )
            .store(in: &cancellables)
    }
}

struct ProductListView: View {
    @StateObject var vm = ProductListViewModel()
    
    var body: some View {
        List(vm.products) { product in
            ProductRow(product: product)
        }
        .onAppear { vm.loadProducts() }
        .searchable(text: $vm.searchText)
    }
}
```

**Winner: Swift Concurrency** — SwiftUI được thiết kế với async/await in mind (`.task`, `.refreshable`, `.task(id:)`).

---

## 11. Real-world Pattern: Khi nào dùng gì

### Dùng Swift Concurrency khi

```
✅ API calls (one-shot network requests)
✅ File I/O (read/write)
✅ Database queries
✅ Image processing
✅ Concurrent operations (TaskGroup)
✅ Background work cần cancel khi navigate away
✅ Bất kỳ operation nào "bắt đầu → kết thúc"
```

### Dùng Combine khi

```
✅ Form validation (combineLatest nhiều fields)
✅ Search with debounce
✅ Real-time data binding (ViewModel → View)
✅ Event streams cần transform phức tạp
✅ Timer-based operations
✅ Notification observation
✅ KVO observation
```

### Production: Dùng CẢ HAI

Thực tế trong production, hầu hết iOS project dùng **cả hai** — mỗi cái cho thế mạnh của nó:

```swift
@MainActor
class ProductSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var products: [Product] = []
    @Published var isLoading = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // COMBINE: reactive binding cho search text → debounce
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self else { return }
                // SWIFT CONCURRENCY: actual API call
                Task { await self.search(query: query) }
            }
            .store(in: &cancellables)
    }
    
    // SWIFT CONCURRENCY: async operation
    func search(query: String) async {
        guard !query.isEmpty else {
            products = []
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Concurrent: search products + fetch suggestions
            async let searchResults = api.searchProducts(query: query)
            async let suggestions = api.fetchSuggestions(query: query)
            
            let (results, _) = try await (searchResults, suggestions)
            products = results
        } catch {
            // Error handling
        }
    }
}
```

Pattern trên là rất phổ biến: **Combine cho reactive UI binding** (debounce, combineLatest, text changes) → trigger **Swift Concurrency cho actual async work** (API calls, data processing).

---

## 12. Tóm tắt

```
Tiêu chí                  Swift Concurrency         Combine
─────────────────────────  ───────────────────────── ─────────────────────
Bản chất                   Language feature           Framework
One-shot async             ⭐ Rất phù hợp            Verbose
Continuous streams         Cần async-algorithms       ⭐ Rất phù hợp
Concurrency control        ⭐ TaskGroup, async let    Zip, Merge (hạn chế)
Thread safety              ⭐ Actor (compile-time)    Tự quản lý
Error handling             ⭐ try/catch tự nhiên      Operator-based
Cancellation               ⭐ Structured, tự động     Manual (AnyCancellable)
Operators                  Hạn chế (cần package)      ⭐ 100+ built-in
Debugging                  ⭐ Gần như sync code       Stack trace khó đọc
Learning curve             ⭐ Thoải mái hơn           Dốc (paradigm shift)
SwiftUI integration        ⭐ .task, .refreshable     ViewModel + @Published
UIKit integration          Cần bridge thủ công        ⭐ Assign, sink trực tiếp
Apple's direction          ⭐ Tương lai               Maintenance mode
```

Hướng đi của Apple rất rõ ràng: **Swift Concurrency là tương lai**, và Combine đang ở giai đoạn "maintenance mode" — Apple vẫn support nhưng không thêm tính năng mới đáng kể. Với project mới, nên ưu tiên Swift Concurrency cho phần lớn async work, và chỉ dùng Combine khi cần reactive stream manipulation mà Swift Concurrency chưa hỗ trợ tốt.
