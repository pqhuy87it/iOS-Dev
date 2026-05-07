# Combine: `.filter()` & `.tryFilter()` — Giải thích chi tiết

## 1. Bản chất — Chỉ cho value thoả điều kiện đi qua

`filter` kiểm tra từng value bằng closure trả về `Bool`. Value nào `true` → đi qua. Value nào `false` → bị loại bỏ im lặng. Output type **giữ nguyên**, số lượng value **giảm hoặc bằng**.

```
Input:  ──1──2──3──4──5──6──7──8──|
filter({ $0.isMultiple(of: 2) }):
        ─────2─────4─────6─────8──|
         ↑     ↑     ↑     ↑
        bỏ 1  bỏ 3  bỏ 5  bỏ 7
```

Hình dung: **lưới lọc** trên dòng suối — chỉ để cá đúng kích thước qua, cá nhỏ bị chặn lại.

---

## 2. `.filter()` — Closure thuần, không throw

### Cú pháp

```swift
publisher.filter { value -> Bool in
    // return true  → value ĐI QUA
    // return false → value BỊ BỎ
}
```

### Ví dụ cơ bản

```swift
(1...10).publisher
    .filter { $0 > 5 }
    .sink { print($0) }
// 6, 7, 8, 9, 10
```

### Type không đổi

```swift
let pub = [1, 2, 3, 4, 5].publisher    // <Int, Never>
let filtered = pub.filter { $0 > 3 }    // <Int, Never>  ← Output giữ nguyên
//                                         Failure giữ nguyên
//                                         Chỉ SỐ LƯỢNG value giảm
```

### Nhiều filter chain

```swift
(1...100).publisher
    .filter { $0.isMultiple(of: 3) }    // 3, 6, 9, 12, ..., 99
    .filter { $0.isMultiple(of: 5) }    // 15, 30, 45, 60, 75, 90
    .sink { print($0) }
// 15, 30, 45, 60, 75, 90

// Tương đương:
(1...100).publisher
    .filter { $0.isMultiple(of: 3) && $0.isMultiple(of: 5) }
// Gộp điều kiện gọn hơn, performance tốt hơn (1 closure thay vì 2)
```

---

## 3. `.tryFilter()` — Closure có thể throw

### Cú pháp

```swift
publisher.tryFilter { value -> Bool in
    // return true  → ĐI QUA
    // return false → BỎ
    // throw error  → PIPELINE FAIL ngay lập tức
}
```

### Ví dụ

```swift
["10", "abc", "30", "40"].publisher
    .tryFilter { str -> Bool in
        guard let num = Int(str) else {
            throw ParseError.invalidNumber(str)
        }
        return num > 20
    }
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// "10" → Int("10") = 10, 10 > 20 = false → bỏ
// "abc" → Int("abc") = nil → THROW → pipeline fail
// Output:
// Completion: failure(ParseError.invalidNumber("abc"))
```

### Failure nới thành `Error`

```swift
[1, 2, 3].publisher                     // <Int, Never>
    .tryFilter { _ in true }             // <Int, Error>
//                                         ↑ Never → Error

URLSession.shared.dataTaskPublisher(for: url)  // <(Data,Response), URLError>
    .tryFilter { ... }                          // <(Data,Response), Error>
//                                                 ↑ URLError → Error
```

Dùng `mapError` sau nếu cần concrete error type:

```swift
publisher
    .tryFilter { ... }                                    // <T, Error>
    .mapError { $0 as? MyError ?? .unknown }              // <T, MyError>
```

---

## 4. Ba kịch bản kết quả của tryFilter

### Return `true` → value đi qua

```swift
// "30" → Int = 30, 30 > 20 → true → "30" đi qua downstream
```

### Return `false` → value bị bỏ (im lặng)

```swift
// "10" → Int = 10, 10 > 20 → false → "10" bị bỏ
// Downstream KHÔNG nhận gì, KHÔNG có error
```

### Throw → pipeline fail ngay

```swift
// "abc" → Int = nil → throw → completion(.failure(...))
// Tất cả value sau → KHÔNG được xử lý
```

```
Input:     ──"10"──"abc"──"30"──"40"──|

tryFilter:
  "10"  → false → bỏ
  "abc" → THROW → ✗ pipeline fail
  "30"  → (không xử lý)
  "40"  → (không xử lý)

Output:    ──✗(ParseError)
```

---

## 5. filter vs compactMap — Khi nào dùng cái nào

### filter: giữ/bỏ dựa trên ĐIỀU KIỆN, value không đổi

```swift
[1, 2, 3, 4, 5].publisher
    .filter { $0 > 3 }
    .sink { print($0) }
// 4, 5 (type: Int, value giữ nguyên)
```

### compactMap: TRANSFORM + loại nil

```swift
["1", "2", "abc", "4"].publisher
    .compactMap { Int($0) }
    .sink { print($0) }
// 1, 2, 4 (type: Int ← khác String, "abc" → nil → bỏ)
```

### So sánh

```
                filter                          compactMap
                ──────                          ──────────
Closure         (Value) -> Bool                 (Value) -> T?
Output type     GIỮA NGUYÊN (Value)             CÓ THỂ KHÁC (T)
Loại bỏ khi     Closure trả false               Closure trả nil
Transform?      ❌ Không                         ✅ Có
```

```swift
// Muốn: chỉ giữ số chẵn (không transform)
// → filter ✅
[1,2,3,4].publisher.filter { $0.isMultiple(of: 2) }    // 2, 4 (Int)

// Muốn: parse String → Int, bỏ cái parse fail (transform + lọc)
// → compactMap ✅
["1","abc","3"].publisher.compactMap { Int($0) }        // 1, 3 (Int)

// Muốn: chỉ giữ số chẵn + chuyển thành String
// → filter + map, HOẶC compactMap
[1,2,3,4].publisher
    .filter { $0.isMultiple(of: 2) }
    .map { String($0) }            // "2", "4"

[1,2,3,4].publisher
    .compactMap { $0.isMultiple(of: 2) ? String($0) : nil }    // "2", "4"
```

---

## 6. filter vs removeDuplicates

```swift
// filter: loại value dựa trên ĐIỀU KIỆN TỪ VALUE
[1, 1, 2, 2, 3].publisher
    .filter { $0 > 1 }
    .sink { print($0) }
// 2, 2, 3 (tất cả > 1 đi qua, KỂ CẢ trùng)

// removeDuplicates: loại value TRÙNG LIÊN TIẾP
[1, 1, 2, 2, 3].publisher
    .removeDuplicates()
    .sink { print($0) }
// 1, 2, 3 (bỏ trùng liên tiếp)
```

```
Input:            ──1──1──2──2──3──|
filter(> 1):      ─────────2──2──3──|      (giữ tất cả > 1)
removeDuplicates: ──1─────2─────3──|       (bỏ trùng liên tiếp)
```

Hai operator phục vụ mục đích khác nhau — thường kết hợp cả hai:

```swift
$searchQuery
    .removeDuplicates()          // bỏ query trùng liên tiếp
    .filter { !$0.isEmpty }      // bỏ query rỗng
```

---

## 7. Ứng dụng thực tế

### 7.1 Search — Lọc query rỗng

```swift
class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [Item] = []
    
    init(api: SearchAPI) {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // ↑ Bỏ query rỗng / chỉ có whitespace → không gọi API thừa
            .flatMap { query in
                api.search(query).catch { _ in Just([]) }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$results)
    }
}
```

```
$query:        ──""──"S"──"Sw"──"  "──"Swift"──""──
removeDup:     ──""──"S"──"Sw"──"  "──"Swift"──""──
filter(!empty):──────"S"──"Sw"────────"Swift"───────
debounce:      ──────────────────────"Swift"────────
               ↑ "" và "  " bị lọc → KHÔNG gọi API cho query rỗng
```

### 7.2 Notification — Chỉ lắng nghe loại quan trọng

```swift
NotificationCenter.default
    .publisher(for: .newMessage)
    .compactMap { $0.userInfo?["message"] as? Message }
    .filter { $0.priority == .high || $0.priority == .critical }
    // ↑ Chỉ giữ message quan trọng
    .sink { [weak self] message in
        self?.showBanner(message)
    }
    .store(in: &cancellables)
```

### 7.3 Form validation — Chỉ submit khi valid

```swift
class FormViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    
    let submitTapped = PassthroughSubject<Void, Never>()
    
    init(api: AuthAPI) {
        submitTapped
            .map { [weak self] _ in
                guard let self else { return false }
                return self.email.contains("@") && self.password.count >= 8
            }
            .filter { $0 == true }
            // ↑ Chỉ cho submit qua khi form valid
            .flatMap { [weak self] _ -> AnyPublisher<AuthResult, Never> in
                guard let self else { return Empty().eraseToAnyPublisher() }
                return api.login(email: self.email, password: self.password)
                    .catch { _ in Just(.failure) }
                    .eraseToAnyPublisher()
            }
            .sink { result in handleResult(result) }
            .store(in: &cancellables)
    }
}
```

### 7.4 Sensor data — Lọc nhiễu

```swift
accelerometerPublisher
    .filter { acceleration in
        // Bỏ qua micro-movements (nhiễu)
        abs(acceleration.x) > 0.1 ||
        abs(acceleration.y) > 0.1 ||
        abs(acceleration.z) > 0.1
    }
    .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
    .sink { [weak self] acceleration in
        self?.handleSignificantMotion(acceleration)
    }
    .store(in: &cancellables)
```

### 7.5 tryFilter — Validate với external service

```swift
userInputPublisher
    .tryFilter { input in
        // Database check có thể throw
        let exists = try database.checkExists(input.username)
        guard !exists else {
            throw ValidationError.usernameTaken(input.username)
        }
        // Nếu không exists → return true → cho qua để tạo account
        return true
    }
    .mapError { $0 as? ValidationError ?? .unknown }
    .sink(
        receiveCompletion: { completion in
            if case .failure(.usernameTaken(let name)) = completion {
                showError("Username '\(name)' is already taken")
            }
        },
        receiveValue: { validInput in
            createAccount(validInput)
        }
    )
    .store(in: &cancellables)
```

### 7.6 Network response — Lọc theo status code

```swift
URLSession.shared.dataTaskPublisher(for: url)
    .tryFilter { data, response in
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIError.httpError(http.statusCode)
        }
        return true    // status OK → cho data qua
    }
    .map(\.0)    // (Data, URLResponse) → Data
    .decode(type: User.self, decoder: JSONDecoder())
    .sink(...)
```

### 7.7 Real-time data — Chỉ xử lý khi thay đổi đáng kể

```swift
// GPS coordinates — chỉ emit khi di chuyển > 10 mét
locationPublisher
    .scan((previous: CLLocation?.none, current: CLLocation?.none)) { state, newLocation in
        (previous: state.current, current: newLocation)
    }
    .filter { state in
        guard let prev = state.previous, let curr = state.current else {
            return true    // first location → luôn emit
        }
        return curr.distance(from: prev) > 10    // > 10 mét mới emit
    }
    .compactMap(\.current)
    .sink { [weak self] location in
        self?.updateMap(location)
    }
    .store(in: &cancellables)
```

### 7.8 Combine filter với các operators khác — Pipeline thực tế

```swift
class StockViewModel: ObservableObject {
    @Published private(set) var alerts: [StockAlert] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(priceStream: AnyPublisher<StockPrice, Never>) {
        priceStream
            .filter { $0.volume > 1_000_000 }
            // ↑ Chỉ quan tâm cổ phiếu volume lớn
            .filter { abs($0.changePercent) > 5.0 }
            // ↑ Chỉ quan tâm biến động > 5%
            .removeDuplicates { $0.symbol == $1.symbol }
            // ↑ Mỗi symbol chỉ alert 1 lần liên tiếp
            .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: true)
            // ↑ Tối đa 1 alert / 10 giây
            .map { price in
                StockAlert(
                    symbol: price.symbol,
                    message: "\(price.symbol): \(price.changePercent > 0 ? "+" : "")\(price.changePercent)%"
                )
            }
            .scan([StockAlert]()) { alerts, newAlert in
                (alerts + [newAlert]).suffix(50)    // giữ 50 gần nhất
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$alerts)
    }
}
```

```
priceStream:        ──AAPL(2%)──TSLA(8%)──GOOG(1%)──TSLA(10%)──META(7%)──
filter(vol>1M):     ──AAPL(2%)──TSLA(8%)─────────────TSLA(10%)──META(7%)──
filter(change>5%):  ────────────TSLA(8%)──────────────TSLA(10%)──META(7%)──
removeDup(symbol):  ────────────TSLA(8%)──────────────────────────META(7%)──
throttle(10s):      ────────────TSLA(8%)──────────────────────────META(7%)──
map → alert:        ────────────alert1────────────────────────────alert2────
scan → [alerts]:    ────────────[a1]──────────────────────────────[a1,a2]──
```

---

## 8. Completion Behavior

### filter không ảnh hưởng completion

```swift
// Upstream complete → filter forward .finished (dù đã bỏ hết value)
[1, 2, 3].publisher
    .filter { $0 > 10 }    // bỏ tất cả
    .sink(
        receiveCompletion: { print($0) },    // finished ✅
        receiveValue: { print($0) }           // KHÔNG gọi
    )
// Output: finished
```

### Upstream fail → forward error

```swift
let subject = PassthroughSubject<Int, MyError>()

subject
    .filter { $0 > 0 }
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
    .store(in: &cancellables)

subject.send(5)                                    // 5 ✅
subject.send(-1)                                   // bỏ (< 0)
subject.send(completion: .failure(.networkError))   // failure ✅
// Error đi qua filter bình thường — filter chỉ lọc VALUE, không lọc ERROR
```

### tryFilter throw → fail ngay

```swift
// throw trong tryFilter → pipeline fail, bỏ qua tất cả value sau
```

---

## 9. Sai lầm thường gặp

### ❌ Filter bỏ hết value → sink không nhận gì (bug im lặng)

```swift
// Tất cả value bị filter → receiveValue KHÔNG BAO GIỜ gọi
// Nếu logic phụ thuộc vào receiveValue → bug im lặng
$data
    .filter { $0.isValid }    // nếu data luôn invalid → không output
    .sink { validData in
        process(validData)     // KHÔNG BAO GIỜ chạy
    }
    .store(in: &cancellables)

// ✅ Thêm handleEvents hoặc log để debug
$data
    .handleEvents(receiveOutput: { print("Before filter: \($0)") })
    .filter { $0.isValid }
    .handleEvents(receiveOutput: { print("After filter: \($0)") })
    .sink { ... }
```

### ❌ Side effect trong filter closure

```swift
// ❌ Filter closure nên PURE — chỉ return Bool
.filter { value in
    self.counter += 1        // ❌ side effect
    logToAnalytics(value)    // ❌ side effect
    return value > 0
}

// ✅ Side effect ở handleEvents
.handleEvents(receiveOutput: { logToAnalytics($0) })
.filter { $0 > 0 }
```

### ❌ Nhầm filter với first(where:)

```swift
// filter: TẤT CẢ value match đi qua (stream tiếp tục)
[1, 2, 3, 4, 5].publisher
    .filter { $0 > 3 }
    .sink { print($0) }
// 4, 5 (CẢ HAI)

// first(where:): CHỈ value ĐẦU TIÊN match (cancel upstream)
[1, 2, 3, 4, 5].publisher
    .first(where: { $0 > 3 })
    .sink { print($0) }
// 4 (CHỈ MỘT, rồi dừng)
```

### ❌ Dùng tryFilter khi không cần throw

```swift
// ❌ Thừa: tryFilter nới Failure → Error không cần thiết
.tryFilter { $0 > 0 }    // <Int, Error> — Failure bị nới dù không throw

// ✅ Dùng filter nếu closure không throw
.filter { $0 > 0 }       // <Int, Never> — Failure giữ nguyên
```

---

## 10. Tóm tắt

| | `filter` | `tryFilter` |
|---|---|---|
| **Closure** | `(Value) -> Bool` | `(Value) throws -> Bool` |
| **Throw?** | ❌ | ✅ → pipeline fail |
| **Failure output** | Giữ nguyên | Nới thành `Error` |
| **true** | Value đi qua | Value đi qua |
| **false** | Value bị bỏ im lặng | Value bị bỏ im lặng |
| **throw** | — | Pipeline fail ngay |
| **Output type** | Giữ nguyên upstream | Giữ nguyên upstream |
| **Completion** | Forward nguyên vẹn | Forward nguyên vẹn |
| **Dùng khi** | Lọc theo điều kiện đơn giản | Lọc cần I/O, parse, validate có thể fail |

| So sánh | filter | compactMap | first(where:) | removeDuplicates |
|---|---|---|---|---|
| Mục đích | Giữ/bỏ theo Bool | Transform + bỏ nil | Lấy 1 match đầu | Bỏ trùng liên tiếp |
| Output type | Giữ nguyên | Có thể khác | Giữ nguyên | Giữ nguyên |
| Số value qua | 0...N | 0...N | 0 hoặc 1 | 0...N |
| Cancel upstream | ❌ | ❌ | ✅ | ❌ |

---

`filter` và `tryFilter` là cặp operator lọc value cơ bản nhất trong Combine, Huy. Ba điểm cốt lõi:

**`filter` chỉ làm 1 việc:** closure trả `true` → value đi qua, `false` → bị bỏ **im lặng** (downstream không biết value đó tồn tại). Output type giữ nguyên, Failure giữ nguyên, chỉ số lượng value giảm. Đây là điểm khác `compactMap` — `compactMap` vừa transform vừa lọc nil, output type có thể khác.

**`tryFilter` thêm khả năng throw:** Closure có thể throw error → pipeline **fail ngay lập tức**, value sau đó không được xử lý. Đổi lại, Failure nới thành `Error`. Dùng khi điều kiện lọc cần operation có thể fail (database check, parse, network validation). Nếu closure chỉ so sánh đơn giản (`$0 > 5`, `$0.isEmpty`) → dùng `filter` thường, tránh nới Failure không cần thiết.

**Sai lầm phổ biến nhất: filter bỏ hết value → bug im lặng.** Nếu tất cả value bị lọc, `receiveValue` không bao giờ được gọi — không có error, không warning. Logic phụ thuộc vào `receiveValue` sẽ "chết" mà không ai biết. Debug tip: đặt `.handleEvents(receiveOutput: { print("Before: \($0)") })` trước và sau `filter` để xem value có đi qua không.

Phân biệt với `first(where:)`: `filter` cho **TẤT CẢ** value match đi qua (stream tiếp tục), `first(where:)` chỉ lấy **1 value đầu tiên** match rồi cancel upstream.
