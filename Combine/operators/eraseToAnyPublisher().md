# Combine: `.eraseToAnyPublisher()` — Giải thích chi tiết

## 1. Vấn đề — Concrete type quá phức tạp

Mỗi operator trong Combine tạo ra **publisher mới** với concrete type lồng nhau. Chỉ vài operator đã tạo ra type khổng lồ:

```swift
let publisher = URLSession.shared.dataTaskPublisher(for: url)
    .map(\.data)
    .decode(type: [User].self, decoder: JSONDecoder())
    .receive(on: DispatchQueue.main)
```

Concrete type thực sự của `publisher`:

```swift
Publishers.ReceiveOn<
    Publishers.Decode<
        Publishers.MapKeyPath<
            URLSession.DataTaskPublisher,
            Data
        >,
        [User],
        JSONDecoder
    >,
    DispatchQueue
>
```

Thử viết làm return type:

```swift
// ❌ Không ai muốn viết thế này
func fetchUsers() -> Publishers.ReceiveOn<Publishers.Decode<Publishers.MapKeyPath<
    URLSession.DataTaskPublisher, Data>, [User], JSONDecoder>, DispatchQueue> {
    // ...
}
```

Mỗi khi thêm/bớt operator → **type thay đổi hoàn toàn** → phải sửa signature → tất cả caller bị ảnh hưởng.

---

## 2. Giải pháp — `eraseToAnyPublisher()`

### Bản chất

`eraseToAnyPublisher()` wrap bất kỳ publisher nào thành `AnyPublisher<Output, Failure>` — **giấu** toàn bộ concrete type, chỉ giữ lại Output và Failure.

```swift
func fetchUsers() -> AnyPublisher<[User], Error> {
    //                  ↑ đơn giản: chỉ cần biết Output và Failure
    URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: [User].self, decoder: JSONDecoder())
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    //  ↑ wrap → AnyPublisher<[User], Error>
}
```

### Cơ chế: Type Erasure

```
TRƯỚC eraseToAnyPublisher():
┌─────────────────────────────────────────────────────────┐
│ Publishers.ReceiveOn<Publishers.Decode<Publishers.Map... │  ← concrete type đầy đủ
│ Output = [User]                                         │
│ Failure = Error                                         │
└─────────────────────────────────────────────────────────┘

SAU eraseToAnyPublisher():
┌─────────────────────────────────┐
│ AnyPublisher<[User], Error>     │  ← chỉ giữ Output + Failure
│ (concrete type bị giấu bên trong) │
└─────────────────────────────────┘
```

**Type Erasure** = pattern giấu concrete type đằng sau wrapper chung. Tương tự `AnyView`, `AnySequence`, `AnyHashable` trong Swift — giấu chi tiết, chỉ giữ interface.

---

## 3. Khi nào BẮT BUỘC dùng

### 3.1 Return type của function / property

```swift
// ❌ Không thể dùng some Publisher trong nhiều trường hợp
// (some Publisher giấu type nhưng bị hạn chế hơn)
protocol UserService {
    func fetchUsers() -> some Publisher  // ❌ Protocol không cho some ở return (trước Swift 5.7)
}

// ✅ AnyPublisher — luôn hoạt động
protocol UserService {
    func fetchUsers() -> AnyPublisher<[User], Error>
}

class APIUserService: UserService {
    func fetchUsers() -> AnyPublisher<[User], Error> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [User].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

class MockUserService: UserService {
    func fetchUsers() -> AnyPublisher<[User], Error> {
        Just([User.mock])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
        // Concrete type KHÁC hoàn toàn APIUserService
        // Nhưng return type giống: AnyPublisher<[User], Error>
    }
}
```

### 3.2 Lưu publisher vào property

```swift
class ViewModel: ObservableObject {
    // ❌ Không thể khai báo type cụ thể cho property
    // var searchPublisher: Publishers.SwitchToLatest<Publishers.Map<...>> ???
    
    // ✅ AnyPublisher
    var searchPublisher: AnyPublisher<[Item], Never>
    
    init() {
        searchPublisher = $query
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap { query in api.search(query).catch { _ in Just([]) } }
            .eraseToAnyPublisher()
    }
}
```

### 3.3 Hai nhánh trả về publisher khác concrete type

```swift
func getData(useCache: Bool) -> AnyPublisher<[Item], Error> {
    if useCache {
        // Concrete type: Just<[Item]> (sau setFailureType)
        return Just(cachedItems)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    } else {
        // Concrete type: Publishers.Decode<Publishers.Map<...>>
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Item].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    // Cả hai nhánh → AnyPublisher<[Item], Error> → cùng type ✅
}
```

Không có `eraseToAnyPublisher()` → hai nhánh trả về **type khác nhau** → compile error.

### 3.4 Collection / Array chứa publishers

```swift
// ❌ Mỗi publisher có concrete type khác → không cho vào cùng array
let publishers = [
    Just(1).map { $0 * 2 },          // Publishers.Map<Just<Int>, Int>
    [3, 4].publisher.filter { $0 > 3 } // Publishers.Filter<Publishers.Sequence<[Int], Never>>
]
// Error: heterogeneous types

// ✅ Erase tất cả về cùng AnyPublisher
let publishers: [AnyPublisher<Int, Never>] = [
    Just(1).map { $0 * 2 }.eraseToAnyPublisher(),
    [3, 4].publisher.filter { $0 > 3 }.eraseToAnyPublisher()
]

// Giờ có thể MergeMany
Publishers.MergeMany(publishers)
    .sink { print($0) }
```

---

## 4. Khi nào KHÔNG CẦN dùng

### 4.1 Pipeline nội bộ — subscribe ngay tại chỗ

```swift
// ✅ Không cần erase — subscribe ngay, không expose ra ngoài
$query
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .removeDuplicates()
    .sink { [weak self] query in self?.search(query) }
    .store(in: &cancellables)
// ← Không cần eraseToAnyPublisher vì không ai cần biết concrete type
```

### 4.2 Operator chain tiếp tục

```swift
// ✅ eraseToAnyPublisher chỉ cần ở CUỐI, trước khi expose
api.fetchUsers()                      // AnyPublisher<[User], Error>
    .map { $0.filter(\.isActive) }    // chain tiếp trên AnyPublisher
    .replaceError(with: [])
    .assign(to: &$activeUsers)
// ← fetchUsers() đã erase, các operator sau chain bình thường
```

### 4.3 Trong body của View

```swift
struct MyView: View {
    var body: some View {
        Text("Hello")
            .onReceive(timer.publisher) { date in ... }
        // ← không cần erase, dùng trực tiếp
    }
}
```

---

## 5. `eraseToAnyPublisher()` vs `some Publisher` (Swift 5.7+)

Swift 5.7 cho phép `some` ở nhiều vị trí hơn:

```swift
// some Publisher — giấu type nhưng compiler vẫn biết bên trong
func fetchUsers() -> some Publisher<[User], Error> {
    URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: [User].self, decoder: JSONDecoder())
    // Không cần eraseToAnyPublisher()
}
```

### So sánh

```
                          AnyPublisher              some Publisher
                          ────────────              ──────────────
Compiler biết concrete    ❌ Không (type-erased)    ✅ Có (opaque)
type bên trong?

Performance               Nhẹ overhead              Zero overhead
                          (existential box)          (static dispatch)

Dùng trong protocol?      ✅ Luôn được              ⚠️ Hạn chế (Swift 5.7+)

Lưu vào property?         ✅ Dễ dàng               ❌ Không (opaque không lưu được)
                          var p: AnyPublisher<>     var p: some Publisher ← error

Hai nhánh if/else         ✅ Cùng type              ❌ Mỗi nhánh khác type
return khác nhau?

Array chứa publishers?    ✅ [AnyPublisher<>]       ❌ Không đồng nhất

Phổ biến trong            ✅ Rất phổ biến           Mới, chưa mainstream
production?
```

**Quy tắc thực tế:** Dùng `AnyPublisher` cho mọi **public API** (protocol, function signature, property). Dùng `some Publisher` khi function đơn giản, một nhánh, và muốn tối ưu performance.

---

## 6. Cách hoạt động bên trong — Type Erasure Pattern

`AnyPublisher` bên trong sử dụng pattern **box erasure**:

```swift
// Đơn giản hoá cơ chế bên trong:
struct AnyPublisher<Output, Failure: Error>: Publisher {
    // Giữ closure thay vì concrete type
    private let _subscribe: (AnySubscriber<Output, Failure>) -> Void
    
    init<P: Publisher>(_ publisher: P)
        where P.Output == Output, P.Failure == Failure {
        // Capture publisher vào closure
        _subscribe = { subscriber in
            publisher.subscribe(subscriber)
        }
    }
    
    func receive<S: Subscriber>(subscriber: S)
        where S.Input == Output, S.Failure == Failure {
        _subscribe(AnySubscriber(subscriber))
    }
}
```

```
TRƯỚC:
Publishers.Map<Just<Int>, String>
  ↓ có type info đầy đủ → static dispatch → nhanh

SAU eraseToAnyPublisher():
AnyPublisher<String, Never>
  ↓ type info bị giấu → dynamic dispatch qua closure → nhẹ overhead
```

Overhead rất nhỏ — trong hầu hết app, **không đáng lo**.

---

## 7. Ví dụ thực tế hoàn chỉnh — Service Layer

### Protocol định nghĩa API

```swift
protocol ProductService {
    func fetchProducts(category: String) -> AnyPublisher<[Product], ServiceError>
    func fetchProductDetail(id: String) -> AnyPublisher<Product, ServiceError>
    func searchProducts(query: String) -> AnyPublisher<[Product], ServiceError>
}
```

### Implementation thực

```swift
class APIProductService: ProductService {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    func fetchProducts(category: String) -> AnyPublisher<[Product], ServiceError> {
        let url = Endpoint.products(category: category).url
        
        return session.dataTaskPublisher(for: url)       // DataTaskPublisher
            .tryMap { data, response in                   // Publishers.TryMap<...>
                guard let http = response as? HTTPURLResponse,
                      200..<300 ~= http.statusCode else {
                    throw ServiceError.badResponse
                }
                return data
            }
            .decode(type: [Product].self, decoder: decoder)  // Publishers.Decode<...>
            .mapError { error -> ServiceError in              // Publishers.MapError<...>
                switch error {
                case is DecodingError: return .decodingFailed
                case let e as ServiceError: return e
                default: return .network(error)
                }
            }
            .eraseToAnyPublisher()
            // ↑ Concrete type cực dài → AnyPublisher<[Product], ServiceError>
    }
    
    func searchProducts(query: String) -> AnyPublisher<[Product], ServiceError> {
        // Pipeline KHÁC hoàn toàn nhưng return type GIỐNG
        let url = Endpoint.search(query: query).url
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: SearchResponse.self, decoder: decoder)
            .map(\.products)                        // ← thêm operator
            .mapError { _ in ServiceError.network($0) }
            .eraseToAnyPublisher()
            // ↑ Cùng AnyPublisher<[Product], ServiceError>
    }
}
```

### Mock cho testing

```swift
class MockProductService: ProductService {
    var stubbedProducts: [Product] = []
    var stubbedError: ServiceError?
    
    func fetchProducts(category: String) -> AnyPublisher<[Product], ServiceError> {
        if let error = stubbedError {
            return Fail(error: error)
                .eraseToAnyPublisher()
            // Concrete type: Fail<[Product], ServiceError>
            // Erase → AnyPublisher<[Product], ServiceError> ✅ khớp protocol
        }
        return Just(stubbedProducts)
            .setFailureType(to: ServiceError.self)
            .eraseToAnyPublisher()
        // Concrete type: Publishers.SetFailureType<Just<[Product]>, ServiceError>
        // Erase → AnyPublisher<[Product], ServiceError> ✅ khớp protocol
    }
    
    func fetchProductDetail(id: String) -> AnyPublisher<Product, ServiceError> {
        Just(Product.mock)
            .setFailureType(to: ServiceError.self)
            .eraseToAnyPublisher()
    }
    
    func searchProducts(query: String) -> AnyPublisher<[Product], ServiceError> {
        Just(stubbedProducts.filter { $0.name.contains(query) })
            .setFailureType(to: ServiceError.self)
            .eraseToAnyPublisher()
    }
}
```

### ViewModel không cần biết concrete type

```swift
class ProductListViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    
    private let service: ProductService  // protocol, không biết impl
    private var cancellables = Set<AnyCancellable>()
    
    init(service: ProductService) {
        self.service = service
    }
    
    func loadProducts(category: String) {
        isLoading = true
        
        service.fetchProducts(category: category)
            // ↑ AnyPublisher — ViewModel không biết bên trong là URLSession hay Mock
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                },
                receiveValue: { [weak self] products in
                    self?.products = products
                }
            )
            .store(in: &cancellables)
    }
}
```

### Unit Test

```swift
class ProductListViewModelTests: XCTestCase {
    func testLoadProducts() {
        let mockService = MockProductService()
        mockService.stubbedProducts = [Product.mock]
        
        let vm = ProductListViewModel(service: mockService)
        // ↑ Inject mock — cùng protocol, cùng AnyPublisher return type
        
        vm.loadProducts(category: "electronics")
        
        // Assert...
    }
}
```

---

## 8. Anti-patterns — Sai lầm thường gặp

### ❌ Erase quá sớm, mất khả năng chain operator

```swift
// ❌ Erase rồi mới chain → mất type info, compiler kém tối ưu
let erased = $query.eraseToAnyPublisher()
erased
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .sink { ... }
// Hoạt động nhưng không cần erase ở đây

// ✅ Chain xong hết rồi mới erase (nếu cần)
$query
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .eraseToAnyPublisher()  // erase ở cuối, trước khi expose
```

### ❌ Erase khi không cần

```swift
// ❌ Pipeline nội bộ, subscribe ngay → không cần erase
$query
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .removeDuplicates()
    .eraseToAnyPublisher()   // ← thừa, không ai cần AnyPublisher
    .sink { ... }
    .store(in: &cancellables)

// ✅ Bỏ erase
$query
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .removeDuplicates()
    .sink { ... }
    .store(in: &cancellables)
```

### ❌ Erase hai lần

```swift
// ❌ Erase lồng nhau — thừa, thêm overhead
func fetch() -> AnyPublisher<Data, Error> {
    session.dataTaskPublisher(for: url)
        .map(\.data)
        .eraseToAnyPublisher()        // erase lần 1
        .mapError { $0 as Error }
        .eraseToAnyPublisher()        // erase lần 2 ← thừa
}

// ✅ Chỉ erase 1 lần ở cuối
func fetch() -> AnyPublisher<Data, Error> {
    session.dataTaskPublisher(for: url)
        .map(\.data)
        .mapError { $0 as Error }
        .eraseToAnyPublisher()        // erase 1 lần duy nhất
}
```

---

## 9. Tóm tắt

| Câu hỏi | Trả lời |
|---|---|
| **Là gì?** | Type erasure wrapper — giấu concrete type, chỉ giữ `<Output, Failure>` |
| **Tại sao cần?** | Concrete type của Combine pipeline quá dài và thay đổi khi thêm/bớt operator |
| **Khi nào dùng?** | Function return type, protocol, property, if/else trả publisher khác type, array of publishers |
| **Khi nào KHÔNG dùng?** | Pipeline nội bộ subscribe ngay tại chỗ |
| **Đặt ở đâu?** | **Cuối pipeline**, trước khi expose ra ngoài |
| **Performance?** | Nhẹ overhead (dynamic dispatch), không đáng lo trong hầu hết app |
| **Thay thế?** | `some Publisher` (Swift 5.7+) — zero overhead nhưng hạn chế hơn |

------

`eraseToAnyPublisher()` giải quyết một vấn đề rất thực tế, Huy: concrete type của Combine pipeline **dài không thể viết nổi** và **thay đổi hoàn toàn** mỗi khi thêm/bớt operator.

Cốt lõi: nó wrap bất kỳ publisher nào thành `AnyPublisher<Output, Failure>` — giấu toàn bộ chi tiết bên trong, chỉ giữ lại hai thông tin quan trọng nhất. Nhờ vậy:

**Protocol abstraction** — `APIService` và `MockService` có pipeline bên trong hoàn toàn khác nhau, nhưng cùng return `AnyPublisher<[User], Error>` → ViewModel không cần biết implementation, inject dependency dễ dàng, test dễ dàng.

**If/else trả publisher khác type** — nhánh cache trả `Just`, nhánh network trả `URLSession.DataTaskPublisher` → erase cả hai về cùng `AnyPublisher` → compile OK.

**Quy tắc quan trọng:** luôn đặt `.eraseToAnyPublisher()` ở **cuối pipeline**, chỉ khi cần expose ra ngoài (function return, property, protocol). Pipeline nội bộ subscribe ngay tại chỗ thì **không cần erase** — thừa và thêm overhead (dù rất nhẹ). Cũng tránh erase hai lần liên tiếp — chỉ cần một lần ở cuối là đủ.
