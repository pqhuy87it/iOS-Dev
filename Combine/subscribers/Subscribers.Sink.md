# Combine: `Subscribers.Sink` — Giải thích chi tiết

## 1. Bản chất — Subscriber đa năng nhất

`Sink` là một **concrete class** conform protocol `Subscriber`. Nó là điểm cuối phổ biến nhất của mọi Combine pipeline — nơi value được tiêu thụ thông qua closure.

```
Publisher ──▶ Operator ──▶ Operator ──▶ Subscribers.Sink
                                            │
                                    receiveValue: { value in
                                        // xử lý value
                                    }
                                    receiveCompletion: { completion in
                                        // xử lý kết thúc
                                    }
```

Khi gọi `.sink(...)` trên publisher, bên trong Combine tạo một instance `Subscribers.Sink` và subscribe vào pipeline.

---

## 2. Hai biến thể

### Biến thể 1: `sink(receiveValue:)` — Chỉ nhận value

```swift
publisher.sink(receiveValue: { value in
    print(value)
})
```

**Yêu cầu: `Failure == Never`.** Publisher phải đảm bảo không bao giờ fail. Nếu publisher có thể fail → compile error:

```swift
// ✅ Failure = Never → dùng được
Just(42)
    .sink(receiveValue: { print($0) })

[1, 2, 3].publisher
    .sink(receiveValue: { print($0) })

$query   // @Published → Failure = Never
    .sink(receiveValue: { print($0) })

// ❌ Failure ≠ Never → compile error
URLSession.shared.dataTaskPublisher(for: url)
    .sink(receiveValue: { print($0) })
    // Error: Failure = URLError, không phải Never
```

### Biến thể 2: `sink(receiveCompletion:receiveValue:)` — Nhận cả completion và value

```swift
publisher.sink(
    receiveCompletion: { completion in
        switch completion {
        case .finished:
            print("Done")
        case .failure(let error):
            print("Error: \(error)")
        }
    },
    receiveValue: { value in
        print(value)
    }
)
```

Dùng được với **mọi Failure type**. Bắt buộc dùng khi `Failure ≠ Never`.

### Tại sao tách thành hai biến thể?

```swift
// Nếu chỉ có 1 biến thể (luôn yêu cầu receiveCompletion):
$query  // Failure = Never, KHÔNG BAO GIỜ fail
    .sink(
        receiveCompletion: { _ in },  // ← boilerplate thừa, không bao giờ chạy
        receiveValue: { print($0) }
    )

// Biến thể receiveValue-only loại bỏ boilerplate:
$query
    .sink(receiveValue: { print($0) })  // ← gọn, rõ ý đồ
```

Apple tách để **ergonomic**: khi publisher không fail, không bắt viết completion handler thừa.

---

## 3. Bên trong `Subscribers.Sink` — Class definition

```swift
// Đơn giản hoá từ source code Apple:
extension Subscribers {
    final class Sink<Input, Failure: Error>: Subscriber, Cancellable {
        let receiveCompletion: (Subscribers.Completion<Failure>) -> Void
        let receiveValue: (Input) -> Void
        
        private var subscription: Subscription?
        
        init(
            receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
            receiveValue: @escaping (Input) -> Void
        ) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
        }
        
        // Bước 1: Nhận subscription từ publisher
        func receive(subscription: Subscription) {
            self.subscription = subscription
            subscription.request(.unlimited)    // ← luôn request unlimited
        }
        
        // Bước 2: Nhận từng value
        func receive(_ input: Input) -> Subscribers.Demand {
            receiveValue(input)    // gọi closure của user
            return .none           // không yêu cầu thêm (đã unlimited)
        }
        
        // Bước 3: Nhận completion
        func receive(completion: Subscribers.Completion<Failure>) {
            receiveCompletion(completion)    // gọi closure của user
            subscription = nil               // cleanup
        }
        
        // Cancellable conformance
        func cancel() {
            subscription?.cancel()
            subscription = nil
        }
    }
}
```

### Điểm quan trọng từ implementation

**`request(.unlimited)`** — Sink luôn yêu cầu **tất cả** value. Không có back-pressure, không giới hạn. Mọi thứ publisher emit, Sink đều nhận.

**`return .none`** — Sau mỗi value, không yêu cầu demand bổ sung (vì đã unlimited từ đầu).

**Conform `Cancellable`** — Sink có thể cancel, nhưng thực tế ta tương tác qua `AnyCancellable` wrapper.

---

## 4. `AnyCancellable` — Vòng đời của Sink

`.sink()` trả về `AnyCancellable` — wrapper quản lý vòng đời subscription:

```swift
let cancellable: AnyCancellable = publisher
    .sink(receiveValue: { print($0) })
```

### AnyCancellable làm gì?

```swift
// Đơn giản hoá:
final class AnyCancellable: Cancellable {
    private let _cancel: () -> Void
    
    init<C: Cancellable>(_ cancellable: C) {
        _cancel = { cancellable.cancel() }
    }
    
    func cancel() { _cancel() }
    
    deinit { cancel() }    // ← TỰ ĐỘNG cancel khi dealloc
}
```

**`deinit { cancel() }`** — Khi `AnyCancellable` bị deallocate → tự động cancel subscription → Sink dừng nhận value → pipeline dừng.

### Ba cách subscription bị huỷ

```
1. AnyCancellable bị dealloc (ra khỏi scope, owner dealloc)
   → deinit → cancel() → pipeline dừng

2. Gọi cancel() thủ công
   → cancellable.cancel() → pipeline dừng

3. Publisher gửi completion (.finished hoặc .failure)
   → pipeline kết thúc tự nhiên → Sink cleanup
```

### Sai lầm #1: Quên giữ AnyCancellable

```swift
func setupBinding() {
    $query
        .sink(receiveValue: { print($0) })
    // ← AnyCancellable không được gán vào biến
    // ← Dealloc cuối function → cancel → Sink chết ngay
    // ← KHÔNG nhận được value nào
}
```

### Giải pháp: `store(in:)`

```swift
private var cancellables = Set<AnyCancellable>()

func setupBinding() {
    $query
        .sink(receiveValue: { print($0) })
        .store(in: &cancellables)
    // ← AnyCancellable sống trong Set
    // ← Set sống cùng object (self)
    // ← Subscription sống cho đến khi object dealloc
}
```

---

## 5. Thứ tự gọi callback — `receiveValue` vs `receiveCompletion`

### Luồng bình thường: value → value → ... → completion

```swift
[1, 2, 3].publisher
    .sink(
        receiveCompletion: { comp in print("Completion: \(comp)") },
        receiveValue: { val in print("Value: \(val)") }
    )
    .store(in: &cancellables)

// Output:
// Value: 1
// Value: 2
// Value: 3
// Completion: finished
```

### Luồng có error: value → ... → failure (dừng ngay)

```swift
["1", "2", "abc", "4"].publisher
    .tryMap { str -> Int in
        guard let n = Int(str) else { throw ParseError.invalid }
        return n
    }
    .sink(
        receiveCompletion: { comp in print("Completion: \(comp)") },
        receiveValue: { val in print("Value: \(val)") }
    )
    .store(in: &cancellables)

// Output:
// Value: 1
// Value: 2
// Completion: failure(ParseError.invalid)
// ← "4" KHÔNG được emit, pipeline đã chết sau error
```

### Publisher vô hạn: value → value → ... (không bao giờ completion)

```swift
Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .sink(receiveValue: { date in
        print("Tick: \(date)")
    })
    .store(in: &cancellables)

// receiveCompletion KHÔNG BAO GIỜ được gọi
// Subscription sống mãi cho đến khi cancel
```

### Quy tắc thứ tự

```
receiveValue    → gọi 0...∞ lần (mỗi value 1 lần)
receiveCompletion → gọi TỐI ĐA 1 lần (khi finished hoặc failure)

Sau receiveCompletion → KHÔNG có receiveValue nào nữa
Publisher vô hạn → receiveCompletion có thể KHÔNG BAO GIỜ được gọi
```

---

## 6. Retain Cycle trong closure — `[weak self]`

### Vấn đề

Sink giữ closure → closure capture `self` → `self` giữ `cancellables` → `cancellables` giữ `AnyCancellable` → `AnyCancellable` giữ Sink → **cycle**:

```
self → cancellables → AnyCancellable → Sink → closure → self
  ↑                                                      │
  └──────────────────── CYCLE ────────────────────────────┘
```

### Giải pháp: `[weak self]`

```swift
class ViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [Item] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // ❌ Strong capture → retain cycle → ViewModel không bao giờ dealloc
        $query
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink(receiveValue: { value in
                self.search(value)       // strong self
            })
            .store(in: &cancellables)
        
        // ✅ Weak capture → không retain cycle
        $query
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink(receiveValue: { [weak self] value in
                self?.search(value)      // weak self
            })
            .store(in: &cancellables)
    }
}
```

### Khi nào KHÔNG cần `[weak self]`?

```swift
// 1. Publisher có giới hạn (sẽ complete) → cycle tạm thời, tự giải phóng
[1, 2, 3].publisher
    .sink { self.process($0) }    // OK: publisher complete ngay → cleanup
    .store(in: &cancellables)

// 2. Không store vào self → không tạo cycle
let cancellable = publisher
    .sink { self.handle($0) }     // cancellable là local → không cycle
// Nhưng subscription chết cuối scope (thường không phải ý muốn)

// 3. Dùng assign(to: &$property) thay vì sink → không có closure
$query.map { $0.uppercased() }
    .assign(to: &$formattedQuery)  // không closure → không capture self
```

### Quy tắc an toàn: luôn `[weak self]` khi cả hai điều kiện đúng

```
1. Closure capture self (trực tiếp hoặc gián tiếp)
   VÀ
2. AnyCancellable được store trong self (self.cancellables)

→ LUÔN dùng [weak self]
```

---

## 7. Sink với Completion pattern phổ biến

### Pattern 1: Loading → Success/Error

```swift
class ProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadProfile() {
        isLoading = true
        errorMessage = nil
        
        api.fetchProfile()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.user = user
                }
            )
            .store(in: &cancellables)
    }
}
```

### Pattern 2: Retry + Fallback

```swift
api.fetchData()
    .retry(2)
    .catch { _ in cacheService.getCachedData() }
    .replaceError(with: [])      // Failure → Never
    .sink(receiveValue: { [weak self] data in
        self?.items = data
    })
    .store(in: &cancellables)
// ← Dùng biến thể receiveValue-only vì replaceError → Never
```

### Pattern 3: Multiple publishers → single sink

```swift
// CombineLatest → sink
Publishers.CombineLatest3($email, $password, $confirmPassword)
    .map { email, pass, confirm in
        !email.isEmpty && pass.count >= 8 && pass == confirm
    }
    .sink(receiveValue: { [weak self] isValid in
        self?.canSubmit = isValid
    })
    .store(in: &cancellables)
```

### Pattern 4: Chuyển đổi pipeline Failure → Never trước sink

```swift
// Pipeline ban đầu: <[User], Error>
// Muốn dùng sink(receiveValue:) → phải biến Failure → Never

api.fetchUsers()                              // <[User], Error>
    .replaceError(with: [])                   // <[User], Never>
    .sink(receiveValue: { [weak self] users in
        self?.users = users
    })
    .store(in: &cancellables)

// HOẶC dùng catch
api.fetchUsers()                              // <[User], Error>
    .catch { error -> Just<[User]> in         // <[User], Never>
        print("Error: \(error)")
        return Just([])
    }
    .sink(receiveValue: { [weak self] users in
        self?.users = users
    })
    .store(in: &cancellables)
```

---

## 8. `sink` vs `assign` vs Custom Subscriber

```swift
// ── sink: nhận value qua closure, linh hoạt nhất ──
publisher
    .sink(receiveValue: { value in
        self.process(value)
        self.log(value)
        self.updateMultipleThings(value)
    })

// ── assign: chỉ gán value vào property, gọn hơn ──
publisher
    .assign(to: \.property, on: object)
// Tương đương:
publisher
    .sink(receiveValue: { object.property = $0 })

// ── assign(to: &$published): an toàn nhất cho @Published ──
publisher
    .assign(to: &$property)
// Không cần store, không retain cycle

// ── Custom Subscriber: kiểm soát demand (back-pressure) ──
class LimitedSubscriber: Subscriber {
    func receive(subscription: Subscription) {
        subscription.request(.max(5))    // chỉ nhận 5 value
    }
    func receive(_ input: Int) -> Subscribers.Demand {
        return .none                     // không yêu cầu thêm
    }
    // ...
}
```

| | `sink` | `assign(to:on:)` | `assign(to:)` | Custom |
|---|---|---|---|---|
| Nhận value | Closure | Gán property | Gán @Published | Tuỳ ý |
| Handle completion | ✅ Có | ❌ Không | ❌ Không | ✅ Có |
| Demand | `.unlimited` | `.unlimited` | `.unlimited` | Tuỳ chỉnh |
| Return | `AnyCancellable` | `AnyCancellable` | Void (tự quản lý) | — |
| Retain cycle risk | Tuỳ closure | ⚠️ Strong ref | ✅ An toàn | Tuỳ impl |
| Dùng khi | Đa mục đích | Gán prop đơn giản | @Published trên self | Back-pressure |

---

## 9. Debug sink — Kỹ thuật troubleshooting

### In mọi event trước sink

```swift
$query
    .print("QUERY")              // in mọi lifecycle event
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .print("AFTER_DEBOUNCE")     // in sau debounce
    .sink(receiveValue: { [weak self] value in
        self?.search(value)
    })
    .store(in: &cancellables)

// Console:
// QUERY: receive subscription
// QUERY: request unlimited
// QUERY: receive value: (S)
// QUERY: receive value: (Sw)
// QUERY: receive value: (Swift)
// AFTER_DEBOUNCE: receive value: (Swift)    ← chỉ value cuối qua debounce
```

### handleEvents: side-effect debug chi tiết

```swift
publisher
    .handleEvents(
        receiveSubscription: { _ in print("📡 Subscribed") },
        receiveOutput: { print("📦 Value: \($0)") },
        receiveCompletion: { print("🏁 Completion: \($0)") },
        receiveCancel: { print("❌ Cancelled") }
    )
    .sink(receiveValue: { ... })
    .store(in: &cancellables)
```

### Kiểm tra sink có thực sự nhận value

```swift
// Đặt breakpoint trong closure
.sink(receiveValue: { value in
    print("✅ Sink received: \(value)")    // breakpoint ở đây
    self?.items = value
})

// Nếu không print → kiểm tra:
// 1. AnyCancellable có được store không?
// 2. Publisher có emit value không? (dùng .print() kiểm tra)
// 3. Pipeline có error ở giữa không? (error → sink không nhận value)
// 4. .receive(on:) có đúng thread không?
```

---

## 10. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | `Subscribers.Sink` — class conform `Subscriber`, tiêu thụ value qua closure |
| **Tạo bằng?** | Gọi `.sink(...)` trên publisher → Combine tạo Sink bên trong |
| **Hai biến thể** | `sink(receiveValue:)` khi `Failure == Never`, `sink(receiveCompletion:receiveValue:)` khi Failure bất kỳ |
| **Demand** | Luôn `.unlimited` — nhận tất cả, không back-pressure |
| **Vòng đời** | Sống cùng `AnyCancellable` — dealloc → cancel → Sink dừng |
| **Retain cycle** | Closure capture `self` + store vào `self.cancellables` → dùng `[weak self]` |
| **Thứ tự callback** | `receiveValue` (0...∞ lần) → `receiveCompletion` (tối đa 1 lần) |

---

`Subscribers.Sink` là subscriber phổ biến nhất trong Combine, Huy — gần như mọi pipeline đều kết thúc bằng `.sink()`. Vài điểm cốt lõi:

**Hai biến thể tồn tại vì lý do ergonomic:** Khi `Failure == Never` (publisher không bao giờ fail), Apple không bắt viết `receiveCompletion` thừa → dùng `sink(receiveValue:)` cho gọn. Khi publisher có thể fail → bắt buộc dùng `sink(receiveCompletion:receiveValue:)` để handle error.

**Bên trong Sink luôn `request(.unlimited)`** — nghĩa là nó nhận tất cả mọi thứ publisher emit, không có back-pressure. Nếu cần kiểm soát demand (chỉ nhận N value), phải viết Custom Subscriber.

**Retain cycle là vấn đề thực tế lớn nhất:** Closure trong sink capture `self` → `self` giữ `cancellables` → `cancellables` giữ `AnyCancellable` → giữ Sink → giữ closure → giữ `self`. Quy tắc: khi closure capture `self` **VÀ** `AnyCancellable` được store trong `self` → **luôn dùng `[weak self]`**. Hoặc thay thế bằng `assign(to: &$property)` để tránh closure hoàn toàn.

**Debug tip quan trọng:** Nếu sink không nhận value, đặt `.print("DEBUG")` trước sink để xem pipeline có emit gì không — thường nguyên nhân là quên `.store(in:)`, error ở giữa pipeline, hoặc publisher chưa emit.
