# Combine: `.assign(to:on:)` — Giải thích chi tiết

## 1. Bản chất — Subscriber tự động gán value vào property

`.assign(to:on:)` là một **Subscriber** (điểm cuối pipeline, giống `sink`). Thay vì nhận value rồi tự xử lý trong closure, nó **tự động gán value vào property** của một object thông qua KeyPath.

```
sink:   publisher ──▶ closure { value in object.property = value }   // tự viết
assign: publisher ──▶ gán thẳng vào object.property                  // tự động
```

Nói cách khác, `assign` là phiên bản **không cần closure** của `sink` khi mục đích duy nhất là gán value vào property.

---

## 2. Cú pháp và thành phần

```swift
publisher.assign(to: \.property, on: object)
//               │       │           │
//               │       │           └── object chứa property (reference type)
//               │       └── KeyPath đến property cần gán
//               └── keyword cố định
```

### `\.property` — KeyPath

KeyPath là cách Swift **tham chiếu đến property theo tên**, không phải theo giá trị:

```swift
let keyPath: ReferenceWritableKeyPath<MyClass, Int> = \.property
//           ↑                         ↑        ↑
//           Phải writable (ghi được)  Type     Property type
//           Phải reference type (class)

// KeyPath cho phép đọc/ghi property một cách dynamic:
object[keyPath: keyPath] = 42    // tương đương object.property = 42
print(object[keyPath: keyPath])  // tương đương print(object.property)
```

### Yêu cầu

| Yêu cầu | Lý do |
|---|---|
| `Failure == Never` | `assign` không handle error — publisher không được fail |
| `on:` phải là **class** (reference type) | Dùng `ReferenceWritableKeyPath` — struct không dùng được |
| Output type == Property type | Publisher emit `Int` → property phải là `Int` |

---

## 3. Phân tích đoạn code

### Bước 1: Publisher

```swift
let publisher2 = [1, 2, 3, 4, 5].publisher
// Type: Publishers.Sequence<[Int], Never>
// Output = Int, Failure = Never
// Emit: 1 → 2 → 3 → 4 → 5 → .finished
```

### Bước 2: Class với didSet observer

```swift
class MyClass {
    var property: Int = 0 {
        didSet {
            print("Did set property to \(property)")
        }
    }
}
```

Mỗi khi `property` được gán giá trị mới → `didSet` chạy → print ra.

### Bước 3: assign kết nối publisher → property

```swift
let object = MyClass()
let subscription3 = publisher2.assign(to: \.property, on: object)
```

Tương đương logic với:

```swift
// assign(to:on:) BÊN TRONG làm điều này:
let subscription3 = publisher2.sink { value in
    object.property = value    // gán từng value vào property
}
```

### Luồng thực thi

```
publisher2 emit 1 → object.property = 1 → didSet: "Did set property to 1"
publisher2 emit 2 → object.property = 2 → didSet: "Did set property to 2"
publisher2 emit 3 → object.property = 3 → didSet: "Did set property to 3"
publisher2 emit 4 → object.property = 4 → didSet: "Did set property to 4"
publisher2 emit 5 → object.property = 5 → didSet: "Did set property to 5"
publisher2 emit .finished → subscription kết thúc
```

Output:

```
Did set property to 1
Did set property to 2
Did set property to 3
Did set property to 4
Did set property to 5
```

---

## 4. So sánh `assign` vs `sink`

```swift
// sink: nhận value trong closure, tự do xử lý
publisher
    .sink { value in
        object.property = value       // phải viết logic gán
        print("Extra logging: \(value)")  // có thể làm thêm việc khác
    }

// assign: chỉ gán value, không làm gì thêm
publisher
    .assign(to: \.property, on: object)   // gọn hơn, rõ ý đồ hơn
```

| | `sink` | `assign(to:on:)` |
|---|---|---|
| Nhận value | Qua closure | Gán thẳng vào property |
| Handle error | ✅ `receiveCompletion` | ❌ Yêu cầu `Failure == Never` |
| Linh hoạt | Làm bất kỳ gì | Chỉ gán property |
| Return type | `AnyCancellable` | `AnyCancellable` |
| Readability | Phải đọc closure | Nhìn KeyPath biết ngay property nào |

---

## 5. ⚠️ Retain Cycle — Vấn đề sống còn

### Vấn đề

`assign(to:on:)` giữ **strong reference** đến object trong `on:`. Nếu object cũng giữ subscription → **retain cycle**:

```swift
class ViewModel: ObservableObject {
    @Published var query = ""
    @Published var result = ""
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // ❌ RETAIN CYCLE:
        // self → cancellables → AnyCancellable → assign giữ strong ref → self
        $query
            .flatMap { self.search($0) }
            .assign(to: \.result, on: self)    // strong reference đến self!
            .store(in: &cancellables)           // self giữ cancellables
        
        // self → cancellables → subscription → self
        //   ↑_________________________________↓  CYCLE → memory leak
    }
}
```

### Giải pháp 1: Dùng `sink` với `[weak self]`

```swift
init() {
    $query
        .flatMap { [weak self] q in self?.search(q) ?? Just("").eraseToAnyPublisher() }
        .sink { [weak self] value in
            self?.result = value          // weak self → không retain cycle
        }
        .store(in: &cancellables)
}
```

### Giải pháp 2: `assign(to: &$property)` — Biến thể không retain cycle

Swift cung cấp overload **khác** dành riêng cho `@Published`:

```swift
init() {
    $query
        .flatMap { [weak self] q in self?.search(q) ?? Just("").eraseToAnyPublisher() }
        .assign(to: &$result)
    //            ↑  ↑
    //            │  └── $result = Published<String>.Publisher
    //            └── inout → KHÔNG giữ strong reference
    //                        KHÔNG trả về AnyCancellable (tự quản lý)
}
```

So sánh hai biến thể:

```
assign(to: \.property, on: object)     assign(to: &$published)
──────────────────────────────         ────────────────────────
Dùng KeyPath + object reference        Dùng inout Published reference
Strong reference → retain cycle risk   KHÔNG strong ref → an toàn
Trả về AnyCancellable                  KHÔNG trả về → tự quản lý lifecycle
Dùng với BẤT KỲ class property         CHỈ dùng với @Published property
Cần .store(in:)                        Không cần store
```

```swift
class ViewModel: ObservableObject {
    @Published var query = ""
    @Published var uppercased = ""
    
    init() {
        // ✅ AN TOÀN: assign(to: &$published) không tạo retain cycle
        $query
            .map { $0.uppercased() }
            .assign(to: &$uppercased)
        // Không cần store, không cần cancellables
        // Subscription tự huỷ khi ViewModel dealloc
    }
}
```

---

## 6. Ví dụ thực tế

### 6a. Bind network data vào ViewModel

```swift
class WeatherViewModel: ObservableObject {
    @Published var city = ""
    @Published private(set) var temperature = "--"
    @Published private(set) var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private let service: WeatherService
    
    init(service: WeatherService = .shared) {
        self.service = service
        
        // assign(to: &$published) — an toàn, không retain cycle
        $city
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .map { [service] city in
                service.fetchTemperature(for: city)
                    .replaceError(with: "--")
            }
            .switchToLatest()
            .assign(to: &$temperature)   // ✅ không cần store
    }
}
```

### 6b. Bind timer vào UI label (assign to:on:)

```swift
class TimerController {
    var elapsedText: String = "" {
        didSet { label.text = elapsedText }
    }
    
    private var cancellable: AnyCancellable?
    private let label: UILabel
    
    init(label: UILabel) {
        self.label = label
        
        // assign(to:on:) — OK vì TimerController KHÔNG giữ trong self
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .map { date in
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                return formatter.string(from: date)
            }
            .assign(to: \.elapsedText, on: self)
        // ⚠️ Cẩn thận: cancellable (self) → subscription → self
        // Nhưng ở đây cancellable là Optional, set nil sẽ break cycle
    }
    
    deinit {
        cancellable = nil    // break cycle khi cần
    }
}
```

### 6c. Nhiều assign trong một pipeline

```swift
class FormViewModel: ObservableObject {
    @Published var email = ""
    @Published private(set) var isEmailValid = false
    @Published private(set) var emailMessage = ""
    
    init() {
        // Pipeline 1: validate email
        $email
            .map { $0.contains("@") && $0.contains(".") }
            .assign(to: &$isEmailValid)
        
        // Pipeline 2: hiển thị message
        $isEmailValid
            .map { $0 ? "Valid email" : "Please enter a valid email" }
            .assign(to: &$emailMessage)
    }
}
```

---

## 7. Khi publisher có thể fail → không dùng được assign

```swift
let networkPublisher: AnyPublisher<String, URLError>  // Failure ≠ Never

// ❌ Compile error: assign yêu cầu Failure == Never
networkPublisher
    .assign(to: \.result, on: viewModel)

// ✅ Chuyển Failure thành Never trước
networkPublisher
    .replaceError(with: "Error occurred")    // Failure → Never
    .assign(to: \.result, on: viewModel)

// Hoặc dùng catch
networkPublisher
    .catch { error -> Just<String> in
        Just("Fallback: \(error.localizedDescription)")
    }
    .assign(to: \.result, on: viewModel)
```

---

## 8. Tóm tắt

| Biến thể | Cú pháp | Retain cycle? | Dùng khi |
|---|---|---|---|
| `assign(to:on:)` | `.assign(to: \.prop, on: obj)` | ⚠️ Có risk (strong ref) | Gán vào property của **object khác** (không phải self) |
| `assign(to:)` | `.assign(to: &$published)` | ✅ An toàn | Gán vào `@Published` property của **chính self** |
| `sink` | `.sink { obj.prop = $0 }` | Tuỳ `[weak self]` | Cần logic phức tạp hơn chỉ gán |

### Quy tắc chọn nhanh

```
Mục đích chỉ là gán value vào property?
    │
    ├── Có → Property là @Published trên self?
    │          │
    │          ├── Có  → .assign(to: &$property) ✅ (an toàn nhất)
    │          │
    │          └── Không → Object khác (không phải self)?
    │                       │
    │                       ├── Có  → .assign(to: \.prop, on: otherObj) ✅
    │                       └── Không (self) → ⚠️ retain cycle risk
    │                                          → dùng sink + [weak self]
    │
    └── Không (cần thêm logic) → .sink { ... } ✅
```

------

`assign(to:on:)` về bản chất là phiên bản "không cần closure" của `sink`, Huy. Khi mục đích duy nhất là gán value vào property, nó gọn và rõ ý đồ hơn.

Trong đoạn code, mỗi khi `publisher2` emit value (1, 2, 3, 4, 5), `assign` tự động gán vào `object.property` → trigger `didSet` → print ra. Tương đương viết `.sink { object.property = $0 }` nhưng declarative hơn.

Điểm quan trọng nhất cần nhớ là **retain cycle**: `assign(to: \.prop, on: self)` giữ **strong reference** đến `self`. Nếu `self` cũng giữ subscription qua `cancellables` → cycle → memory leak. Đây là lý do Swift bổ sung biến thể thứ hai: **`assign(to: &$published)`** — dùng inout reference, không giữ strong ref, không trả `AnyCancellable`, tự quản lý lifecycle. Khi gán vào `@Published` property của chính self trong ViewModel, luôn ưu tiên biến thể này.
