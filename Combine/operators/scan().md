# Combine: `.scan()` — Giải thích chi tiết

## 1. Bản chất — Accumulate và emit MỖI BƯỚC

`scan` nhận một **giá trị khởi tạo** (seed) và một **closure tích luỹ**. Mỗi khi upstream emit value mới, closure nhận **kết quả tích luỹ trước đó** + **value mới** → trả về **kết quả mới** → emit ngay cho downstream.

```swift
publisher.scan(initialValue) { accumulated, newValue -> Result in
    // accumulated: kết quả của lần chạy trước (hoặc initialValue lần đầu)
    // newValue: value mới từ upstream
    // return: kết quả mới → emit downstream + lưu lại cho lần sau
}
```

```
Input:  ──1──2──3──4──5──|
scan(0, +):
        ──1──3──6──10─15─|

Bước 1: accumulated=0,  newValue=1  → 0+1  = 1   → emit 1
Bước 2: accumulated=1,  newValue=2  → 1+2  = 3   → emit 3
Bước 3: accumulated=3,  newValue=3  → 3+3  = 6   → emit 6
Bước 4: accumulated=6,  newValue=4  → 6+4  = 10  → emit 10
Bước 5: accumulated=10, newValue=5  → 10+5 = 15  → emit 15
```

Hình dung: **quả cầu tuyết lăn xuống dốc** — mỗi bước nhặt thêm tuyết (value mới), lớn dần, và ta thấy kích thước quả cầu **tại mỗi bước**.

---

## 2. scan vs reduce — Khác biệt cốt lõi

Cả hai đều tích luỹ, nhưng **emit khác nhau hoàn toàn**:

```
Input:  ──1──2──3──4──5──|

scan(0, +):    ──1──3──6──10──15──|     ← emit MỖI BƯỚC (5 values)
reduce(0, +):  ───────────────15──|     ← emit CHỈ KẾT QUẢ CUỐI (1 value)
```

```
scan:    "Cho tôi xem quá trình tích luỹ"    → stream of intermediate results
reduce:  "Cho tôi kết quả cuối cùng thôi"    → single final result
```

| | `scan` | `reduce` |
|---|---|---|
| Emit khi? | Mỗi value mới | Chỉ khi upstream complete |
| Số lượng emit | = số value upstream | 1 |
| Cần upstream complete? | ❌ Không | ✅ Bắt buộc |
| Publisher vô hạn? | ✅ Hoạt động | ❌ Không bao giờ emit |

---

## 3. Ví dụ minh hoạ từng loại tích luỹ

### 3.1 Running total (cộng dồn)

```swift
[10, 20, 30, 40].publisher
    .scan(0) { sum, value in sum + value }
    .sink { print($0) }
// 10, 30, 60, 100
```

### 3.2 Running count (đếm)

```swift
["A", "B", "C", "D"].publisher
    .scan(0) { count, _ in count + 1 }
    .sink { print($0) }
// 1, 2, 3, 4
```

### 3.3 Running average (trung bình cộng)

```swift
[10.0, 20.0, 30.0, 40.0].publisher
    .scan((sum: 0.0, count: 0)) { state, value in
        (sum: state.sum + value, count: state.count + 1)
    }
    .map { $0.sum / Double($0.count) }
    .sink { print($0) }
// 10.0, 15.0, 20.0, 25.0
```

### 3.4 Running min / max

```swift
[5, 3, 8, 1, 9, 2].publisher
    .scan(Int.max) { currentMin, value in min(currentMin, value) }
    .sink { print($0) }
// 5, 3, 3, 1, 1, 1

[5, 3, 8, 1, 9, 2].publisher
    .scan(Int.min) { currentMax, value in max(currentMax, value) }
    .sink { print($0) }
// 5, 5, 8, 8, 9, 9
```

### 3.5 Collect thành array (running)

```swift
[1, 2, 3, 4].publisher
    .scan([Int]()) { array, value in array + [value] }
    .sink { print($0) }
// [1]
// [1, 2]
// [1, 2, 3]
// [1, 2, 3, 4]
```

### 3.6 String concatenation

```swift
["Hello", " ", "World", "!"].publisher
    .scan("") { accumulated, word in accumulated + word }
    .sink { print($0) }
// "Hello"
// "Hello "
// "Hello World"
// "Hello World!"
```

### 3.7 State machine

```swift
enum State { case idle, loading, loaded(Int), error }
enum Event { case fetch, success(Int), failure }

[Event.fetch, .success(42), .fetch, .failure].publisher
    .scan(State.idle) { state, event -> State in
        switch (state, event) {
        case (_, .fetch):          return .loading
        case (_, .success(let n)): return .loaded(n)
        case (_, .failure):        return .error
        }
    }
    .sink { print($0) }
// loading, loaded(42), loading, error
```

---

## 4. Output type có thể KHÁC input type

`scan` không yêu cầu output cùng type với input — accumulated type (= initial value type) quyết định output:

```swift
// Input: String, Output: Int (đếm ký tự tổng)
["Hi", "Hello", "Hey"].publisher
    .scan(0) { totalChars, word in totalChars + word.count }
    .sink { print($0) }
// 2, 7, 10

// Input: Int, Output: String
[1, 2, 3].publisher
    .scan("") { result, num in result + "\(num)→" }
    .sink { print($0) }
// "1→", "1→2→", "1→2→3→"

// Input: Event, Output: [Event] (history)
eventStream
    .scan([Event]()) { history, event in history + [event] }
    .sink { allEvents in print("History: \(allEvents.count) events") }
```

---

## 5. `tryScan` — scan có thể throw

```swift
publisher.tryScan(initialValue) { accumulated, newValue -> Result in
    // Có thể throw → pipeline fail
}
// Failure nới thành Error (giống mọi try* operator)
```

```swift
["10", "20", "abc", "40"].publisher
    .tryScan(0) { sum, str -> Int in
        guard let num = Int(str) else {
            throw ParseError.invalidNumber(str)
        }
        return sum + num
    }
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
// 10    (0 + 10)
// 30    (10 + 20)
// failure(ParseError.invalidNumber("abc"))
// ← "40" không bao giờ xử lý
```

---

## 6. Ứng dụng thực tế

### 6.1 Tap counter — Đếm số lần tap

```swift
class CounterViewModel: ObservableObject {
    @Published private(set) var tapCount = 0
    let tapped = PassthroughSubject<Void, Never>()
    
    init() {
        tapped
            .scan(0) { count, _ in count + 1 }
            .assign(to: &$tapCount)
    }
}

// View
Button("Tap me (\(vm.tapCount))") {
    vm.tapped.send()
}
```

```
tapped: ──()──()──()──()──()──
scan:   ──1───2───3───4───5───
```

### 6.2 Shopping cart — Running total

```swift
enum CartAction {
    case add(Product)
    case remove(Product)
    case clear
}

class CartViewModel: ObservableObject {
    @Published private(set) var items: [Product] = []
    @Published private(set) var total: Double = 0
    
    let action = PassthroughSubject<CartAction, Never>()
    
    init() {
        action
            .scan([Product]()) { cart, action -> [Product] in
                var updated = cart
                switch action {
                case .add(let product):
                    updated.append(product)
                case .remove(let product):
                    updated.removeAll { $0.id == product.id }
                case .clear:
                    updated.removeAll()
                }
                return updated
            }
            .handleEvents(receiveOutput: { [weak self] items in
                self?.total = items.reduce(0) { $0 + $1.price }
            })
            .assign(to: &$items)
    }
}
```

```
action: ──add(iPhone)──add(Case)──remove(Case)──add(AirPods)──
scan:   ──[iPhone]─────[iPhone,Case]──[iPhone]───[iPhone,AirPods]──
total:  ──999──────────1049───────────999────────1249──────────
```

### 6.3 Undo/Redo history

```swift
struct HistoryState<T> {
    var current: T
    var undoStack: [T]
    var redoStack: [T]
}

enum EditAction {
    case update(String)
    case undo
    case redo
}

class EditorViewModel: ObservableObject {
    @Published private(set) var text = ""
    let action = PassthroughSubject<EditAction, Never>()
    
    init() {
        action
            .scan(HistoryState(current: "", undoStack: [], redoStack: [])) { state, action in
                var new = state
                switch action {
                case .update(let text):
                    new.undoStack.append(state.current)
                    new.current = text
                    new.redoStack.removeAll()
                case .undo:
                    guard let prev = new.undoStack.popLast() else { return state }
                    new.redoStack.append(state.current)
                    new.current = prev
                case .redo:
                    guard let next = new.redoStack.popLast() else { return state }
                    new.undoStack.append(state.current)
                    new.current = next
                }
                return new
            }
            .map(\.current)
            .assign(to: &$text)
    }
}
```

### 6.4 Rate limiter — Theo dõi requests / giây

```swift
class APIRateLimiter {
    private var cancellables = Set<AnyCancellable>()
    
    let requestMade = PassthroughSubject<Void, Never>()
    @Published private(set) var requestsInLastMinute = 0
    
    init() {
        requestMade
            .scan([Date]()) { timestamps, _ in
                let now = Date()
                let oneMinuteAgo = now.addingTimeInterval(-60)
                // Giữ lại timestamps trong 1 phút gần nhất + thêm mới
                return timestamps.filter { $0 > oneMinuteAgo } + [now]
            }
            .map(\.count)
            .assign(to: &$requestsInLastMinute)
    }
    
    var canMakeRequest: Bool {
        requestsInLastMinute < 60    // max 60 requests/phút
    }
}
```

### 6.5 Chat messages — Accumulate vào list

```swift
class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(incomingMessages: AnyPublisher<Message, Never>,
         initialMessages: [Message] = []) {
        
        incomingMessages
            .scan(initialMessages) { allMessages, newMessage in
                allMessages + [newMessage]
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)
    }
}
```

```
initial:   [msg1, msg2]
incoming:  ──msg3──────msg4──────msg5──
scan:      ──[1,2,3]──[1,2,3,4]──[1,2,3,4,5]──
```

### 6.6 Scroll direction detection

```swift
enum ScrollDirection { case up, down, none }

class ScrollViewModel: ObservableObject {
    @Published var scrollOffset: CGFloat = 0
    @Published private(set) var direction: ScrollDirection = .none
    
    init() {
        $scrollOffset
            .scan((previous: CGFloat(0), direction: ScrollDirection.none)) { state, newOffset in
                let dir: ScrollDirection
                if newOffset > state.previous {
                    dir = .down
                } else if newOffset < state.previous {
                    dir = .up
                } else {
                    dir = .none
                }
                return (previous: newOffset, direction: dir)
            }
            .map(\.direction)
            .removeDuplicates()
            .assign(to: &$direction)
    }
}
```

```
scrollOffset: ──0──10──25──40──35──20──30──
scan state:   (prev, dir):
              (0,none)──(10,down)──(25,down)──(40,down)──(35,up)──(20,up)──(30,down)
map(\.dir):   none──down──down──down──up──up──down
removeDup:    none──down──────────────up──────down
```

### 6.7 Debounce-like counter — Đếm events trong window

```swift
// Đếm số lần tap trong 5 giây gần nhất
tapPublisher
    .scan([Date]()) { timestamps, _ in
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        return timestamps.filter { $0 > fiveSecondsAgo } + [Date()]
    }
    .map(\.count)
    .sink { recentTapCount in
        if recentTapCount >= 5 {
            print("Rapid tapping detected!")
        }
    }
    .store(in: &cancellables)
```

### 6.8 Network retry counter

```swift
api.fetchData()
    .catch { error -> AnyPublisher<Data, Error> in
        // Retry logic bên ngoài
    }
    .tryScan((data: Data(), retryCount: 0)) { state, data in
        if data.isEmpty {
            let newCount = state.retryCount + 1
            guard newCount <= 3 else {
                throw AppError.maxRetriesExceeded
            }
            return (data: data, retryCount: newCount)
        }
        return (data: data, retryCount: 0)    // reset counter on success
    }
    .map(\.data)
    .sink(...)
```

---

## 7. scan với complex state — Reducer pattern

`scan` + enum actions = **Redux/Reducer pattern** trong Combine:

```swift
// State
struct AppState: Equatable {
    var count: Int = 0
    var todos: [String] = []
    var isLoading: Bool = false
}

// Actions
enum AppAction {
    case increment
    case decrement
    case addTodo(String)
    case removeTodo(Int)
    case setLoading(Bool)
}

// Reducer (pure function)
func appReducer(state: AppState, action: AppAction) -> AppState {
    var new = state
    switch action {
    case .increment:         new.count += 1
    case .decrement:         new.count -= 1
    case .addTodo(let text): new.todos.append(text)
    case .removeTodo(let i): new.todos.remove(at: i)
    case .setLoading(let v): new.isLoading = v
    }
    return new
}

// Store
class Store: ObservableObject {
    @Published private(set) var state = AppState()
    let dispatch = PassthroughSubject<AppAction, Never>()
    
    init() {
        dispatch
            .scan(AppState()) { state, action in
                appReducer(state: state, action: action)
            }
            .removeDuplicates()
            .assign(to: &$state)
    }
}
```

```
dispatch: ──.increment──.addTodo("Buy")──.increment──.setLoading(true)──
scan:     ──{c:1,t:[]}──{c:1,t:["Buy"]}──{c:2,t:["Buy"]}──{c:2,t:["Buy"],l:true}──
           ↑ mỗi action → state MỚI emit ngay
```

---

## 8. Performance — scan buffer O(1)

```swift
// scan chỉ giữ 1 accumulated value → O(1) memory
// (trừ khi accumulated là array/collection lớn dần)

// ✅ O(1): running sum
.scan(0, +)

// ✅ O(1): tuple state
.scan((prev: 0, dir: .none)) { ... }

// ⚠️ O(N): array tích luỹ — cẩn thận với stream dài
.scan([Message]()) { msgs, new in msgs + [new] }
// Array lớn dần → memory tăng
// Publisher vô hạn + scan collect = memory leak tiềm ẩn

// ✅ Giải pháp: giới hạn size
.scan([Message]()) { msgs, new in
    var updated = msgs + [new]
    if updated.count > 100 {
        updated = Array(updated.suffix(100))    // giữ 100 gần nhất
    }
    return updated
}
```

---

## 9. Sai lầm thường gặp

### ❌ Mutate accumulated trực tiếp (scan là value-based)

```swift
// ❌ Nếu accumulated là class/reference type → side effect nguy hiểm
// scan kỳ vọng closure PURE — không side effect

// ✅ Luôn TẠO GIÁ TRỊ MỚI trong closure
.scan([Int]()) { array, value in
    var new = array       // copy
    new.append(value)     // mutate copy
    return new            // trả về copy
    // KHÔNG mutate `array` trực tiếp
}
```

### ❌ Side effect trong scan closure

```swift
// ❌ Gọi API, update UI trong scan → unpredictable
.scan(0) { sum, value in
    self.updateLabel(sum)    // ❌ side effect
    return sum + value
}

// ✅ Side effect ở operator riêng
.scan(0, +)
.handleEvents(receiveOutput: { self.updateLabel($0) })
// hoặc trong sink
```

### ❌ Dùng scan khi chỉ cần kết quả cuối

```swift
// ❌ Thừa: emit 1000 intermediate results khi chỉ cần kết quả cuối
(1...1000).publisher
    .scan(0, +)              // emit 1000 values
    .last()                   // chỉ lấy cuối → 500500

// ✅ Dùng reduce
(1...1000).publisher
    .reduce(0, +)            // chỉ emit 1 value: 500500
```

---

## 10. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Tích luỹ value qua closure, **emit mỗi bước** |
| **Signature** | `.scan(initial) { accumulated, newValue -> Result }` |
| **Emit** | Mỗi khi upstream emit → closure chạy → result emit ngay |
| **vs reduce** | scan: emit mỗi bước (N values). reduce: chỉ kết quả cuối (1 value) |
| **Output type** | Có thể KHÁC input type — tuỳ initial value + closure return |
| **Publisher vô hạn** | ✅ Hoạt động (reduce thì không) |
| **Memory** | O(1) cho accumulated đơn giản. Cẩn thận O(N) nếu collect vào array |
| **tryScan** | Closure có thể throw → Failure nới thành Error |
| **Dùng khi** | Running total, counter, history, state machine, reducer pattern, direction detection |
| **Closure** | Phải **pure** — không side effect, tạo giá trị mới thay vì mutate |

-----

`scan` là operator tích luỹ **emit mỗi bước**, Huy — khác `reduce` chỉ emit kết quả cuối. Ba điểm cốt lõi:

**Cơ chế:** Mỗi khi upstream emit value mới, closure nhận `(kết quả tích luỹ trước đó, value mới)` → trả về kết quả mới → emit ngay cho downstream VÀ lưu lại cho lần sau. Giá trị khởi tạo (seed) dùng cho lần đầu tiên khi chưa có kết quả trước đó.

**Khác reduce ở điểm sống còn:** `scan` emit **N values** (mỗi bước), `reduce` emit **1 value** (cuối cùng). `scan` hoạt động với publisher vô hạn (Timer, @Published), `reduce` thì không (phải đợi complete). Nếu chỉ cần kết quả cuối → dùng `reduce` tránh emit thừa.

**Sức mạnh thực sự: state machine / reducer pattern.** `scan` + enum actions = Redux-style state management trong Combine. Mỗi action dispatch → scan chạy reducer function → state mới emit → UI cập nhật. Đây là pattern mạnh cho undo/redo, shopping cart, form state, scroll direction detection. Closure phải **pure** (không side effect) — tạo giá trị mới thay vì mutate accumulated, side effect đặt ở `handleEvents` hoặc `sink`.

**Lưu ý memory:** `scan` chỉ buffer 1 accumulated value (O(1)). Nhưng nếu accumulated là array lớn dần (`.scan([]) { $0 + [$1] }`) thì memory tăng O(N) — với publisher vô hạn sẽ thành memory leak. Giải pháp: giới hạn size (`Array(updated.suffix(100))`).
