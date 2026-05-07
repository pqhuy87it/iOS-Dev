# Combine: `.drop(untilOutputFrom:)` — Giải thích chi tiết

## 1. Bản chất — "Cổng chặn" mở bởi publisher khác

`drop(untilOutputFrom:)` **bỏ tất cả value** từ upstream cho đến khi một **publisher khác** (trigger) emit value đầu tiên. Sau khi trigger emit → cổng mở → tất cả value tiếp theo đi qua bình thường.

```
Data stream:    ──A──B──C──D──E──F──G──H──
Trigger:        ─────────────🔔─────────────
                              ↑ trigger emit lần đầu

drop(untilOutputFrom:):
                ─────────────D──E──F──G──H──
                 ↑ bỏ A,B,C   ↑ từ D trở đi: cho qua tất cả
```

Hình dung: **đèn đỏ** chặn xe. Khi publisher khác "bật đèn xanh" → tất cả xe sau đó được đi qua. Đèn xanh chỉ cần bật **1 lần** — sau đó cổng mở vĩnh viễn.

---

## 2. Cú pháp

```swift
publisher
    .drop(untilOutputFrom: triggerPublisher)
//                          ↑ publisher "mở cổng"
//   Bỏ mọi value từ publisher cho đến khi triggerPublisher emit

// Type signature:
// func drop<P: Publisher>(untilOutputFrom trigger: P)
//     -> Publishers.DropUntilOutput<Self, P>
//     where P.Failure == Self.Failure
//                        ↑ Failure phải khớp
```

**Yêu cầu:** Failure type của trigger **phải khớp** với upstream. Output type của trigger **không quan trọng** — chỉ cần emit bất kỳ giá trị gì.

---

## 3. Ví dụ cơ bản từng bước

```swift
let dataStream = PassthroughSubject<String, Never>()
let trigger = PassthroughSubject<Void, Never>()

dataStream
    .drop(untilOutputFrom: trigger)
    .sink { print($0) }
    .store(in: &cancellables)
```

```
Bước 1: dataStream.send("A")
┌─────────────────────────────────┐
│ Cổng: ĐÓNG (trigger chưa emit) │
│ "A" → BỎ ❌                     │
└─────────────────────────────────┘

Bước 2: dataStream.send("B")
┌─────────────────────────────────┐
│ Cổng: ĐÓNG                      │
│ "B" → BỎ ❌                     │
└─────────────────────────────────┘

Bước 3: trigger.send(())          ← 🔔 TRIGGER!
┌─────────────────────────────────┐
│ Cổng: MỞ VĨNH VIỄN ✅          │
│ (trigger value bị bỏ,           │
│  chỉ dùng làm tín hiệu)        │
└─────────────────────────────────┘

Bước 4: dataStream.send("C")
┌─────────────────────────────────┐
│ Cổng: ĐÃ MỞ                    │
│ "C" → ĐI QUA ✅ → sink: "C"    │
└─────────────────────────────────┘

Bước 5: dataStream.send("D")
│ "D" → ĐI QUA ✅ → sink: "D"    │

Bước 6: trigger.send(())         ← trigger emit lần 2
│ Không ảnh hưởng — cổng đã mở   │

Bước 7: dataStream.send("E")
│ "E" → ĐI QUA ✅ → sink: "E"    │
```

**Output: C, D, E** (A và B bị bỏ)

---

## 4. Timing chi tiết — Value "đúng lúc" trigger

```swift
// Nếu dataStream và trigger emit "cùng lúc"?
dataStream.send("X")     // CÓ thể bị bỏ hoặc đi qua
trigger.send(())          // tuỳ thứ tự thực thi

// Quy tắc: value emit TRƯỚC trigger.send() → BỎ
//          value emit SAU trigger.send() → ĐI QUA
//          value emit "cùng lúc" → tuỳ scheduler (thường BỎ)
```

```
Trường hợp rõ ràng:
Data:    ──A──B─────C──D──
Trigger: ──────🔔────────── 
Output:  ───────────C──D──
                    ↑ C emit SAU trigger → đi qua

Trường hợp đồng thời:
Data:    ──A──B|C──D──       (B và trigger gần như cùng lúc)
Trigger: ──────🔔──────
Output:  ──────────D──       (B có thể bị bỏ hoặc đi qua — race condition)
```

---

## 5. Trigger chỉ cần emit 1 lần

Sau khi trigger emit value đầu tiên:

```
1. Cổng mở VĨNH VIỄN — không bao giờ đóng lại
2. Trigger emit thêm → KHÔNG ảnh hưởng
3. drop(untilOutputFrom:) CANCEL subscription với trigger
   (trigger không cần emit nữa)
```

```swift
let trigger = PassthroughSubject<Void, Never>()

trigger
    .handleEvents(receiveCancel: { print("🛑 Trigger cancelled") })
    // ...

// Khi trigger emit lần đầu:
// → cổng mở
// → "🛑 Trigger cancelled" — subscription với trigger bị cancel
// → trigger emit lần 2, 3... → không ảnh hưởng
```

---

## 6. Completion Behavior

### Upstream complete trước trigger → complete, không emit gì

```swift
let data = PassthroughSubject<Int, Never>()
let trigger = PassthroughSubject<Void, Never>()

data.drop(untilOutputFrom: trigger)
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
    .store(in: &cancellables)

data.send(1)                          // bỏ (cổng đóng)
data.send(2)                          // bỏ (cổng đóng)
data.send(completion: .finished)      // Completion: finished
// ← trigger chưa emit, upstream đã complete
// ← Không value nào được emit
```

```
data:    ──1──2──|
trigger: ─────────── (chưa emit)
output:  ────────|   (chỉ completion, không value)
```

### Trigger complete TRƯỚC khi emit → cổng KHÔNG BAO GIỜ mở

```swift
data.drop(untilOutputFrom: trigger)
    .sink(receiveValue: { print($0) })
    .store(in: &cancellables)

trigger.send(completion: .finished)   // trigger complete mà KHÔNG emit value
data.send(1)                          // bỏ? hành vi phụ thuộc implementation
data.send(2)
// ⚠️ Trigger complete không có value → cổng không mở
// Hành vi: upstream complete hoặc values tiếp tục bị bỏ
```

### Upstream fail → forward error

```swift
let data = PassthroughSubject<Int, MyError>()
let trigger = PassthroughSubject<Void, MyError>()

data.drop(untilOutputFrom: trigger)
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
    .store(in: &cancellables)

data.send(1)                                    // bỏ
data.send(completion: .failure(.networkError))   // failure(networkError)
// Error forward bình thường dù cổng đóng
```

### Trigger fail → pipeline cũng fail

```swift
trigger.send(completion: .failure(.networkError))
// → Pipeline fail — trigger error forward downstream
```

---

## 7. Ứng dụng thực tế

### 7.1 Bỏ data cho đến khi user authenticated

```swift
class FeedViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(feedStream: AnyPublisher<Post, Never>,
         authManager: AuthManager) {
        
        // feedStream có thể emit trước khi user login
        // → bỏ tất cả cho đến khi auth thành công
        feedStream
            .drop(untilOutputFrom:
                authManager.$isAuthenticated
                    .filter { $0 == true }
                // ↑ Trigger: emit khi isAuthenticated chuyển thành true
            )
            .scan([Post]()) { posts, newPost in posts + [newPost] }
            .receive(on: DispatchQueue.main)
            .assign(to: &$posts)
    }
}
```

```
feedStream:       ──post1──post2──post3──post4──post5──
$isAuthenticated: ──false──false──true──────────────────
                                  ↑ trigger (filter true)

output:           ────────────────post3──post4──post5──
                   bỏ post1,2     ↑ từ đây cho qua
```

### 7.2 Bỏ sensor data cho đến khi calibration xong

```swift
class MotionTracker {
    private var cancellables = Set<AnyCancellable>()
    
    let calibrationDone = PassthroughSubject<Void, Never>()
    
    func startTracking() {
        motionManager.accelerometerStream
            .drop(untilOutputFrom: calibrationDone)
            // ↑ Sensor data trước calibration không chính xác → bỏ
            .sink { [weak self] acceleration in
                self?.processMotion(acceleration)
            }
            .store(in: &cancellables)
        
        // Bắt đầu calibrate
        performCalibration {
            self.calibrationDone.send(())    // 🔔 mở cổng
        }
    }
}
```

### 7.3 Bỏ events cho đến khi view fully loaded

```swift
struct ComplexDashboard: View {
    @State private var vm = DashboardViewModel()
    
    var body: some View {
        DashboardContent(vm: vm)
            .onAppear { vm.startListening() }
    }
}

class DashboardViewModel {
    let viewDidAppear = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    func startListening() {
        // WebSocket events trước khi view hiện → gây crash/flicker
        webSocket.eventStream
            .drop(untilOutputFrom: viewDidAppear)
            // ↑ Đợi view hiện xong rồi mới xử lý events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
        
        // Trigger khi view sẵn sàng
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.viewDidAppear.send(())
        }
    }
}
```

### 7.4 Bỏ keyboard events cho đến khi user tap vào text field

```swift
class EditorViewModel: ObservableObject {
    @Published var text = ""
    private var cancellables = Set<AnyCancellable>()
    
    let userStartedEditing = PassthroughSubject<Void, Never>()
    
    init(externalInput: AnyPublisher<String, Never>) {
        // External input (paste, voice) trước khi user tap vào editor → bỏ qua
        externalInput
            .drop(untilOutputFrom: userStartedEditing)
            .sink { [weak self] input in
                self?.text += input
            }
            .store(in: &cancellables)
    }
}
```

### 7.5 Network: bỏ response cũ cho đến khi retry trigger

```swift
class RetryViewModel: ObservableObject {
    @Published private(set) var data: Data?
    private var cancellables = Set<AnyCancellable>()
    
    let retryTapped = PassthroughSubject<Void, Never>()
    
    func setupAutoRetry(api: AnyPublisher<Data, Never>) {
        // API có thể emit cached/stale data trước user quyết định retry
        // Chỉ nhận data SAU khi user tap retry
        api
            .drop(untilOutputFrom: retryTapped)
            .first()
            // ↑ Lấy response đầu tiên sau retry → xong
            .receive(on: DispatchQueue.main)
            .assign(to: &$data)
    }
}
```

### 7.6 Game: bỏ input cho đến khi countdown xong

```swift
class GameController {
    private var cancellables = Set<AnyCancellable>()
    
    let countdownFinished = PassthroughSubject<Void, Never>()
    
    func setupControls() {
        // Player tap/swipe trước countdown xong → bỏ qua (cheat prevention)
        playerInputStream
            .drop(untilOutputFrom: countdownFinished)
            .sink { [weak self] input in
                self?.processPlayerInput(input)
            }
            .store(in: &cancellables)
        
        // 3... 2... 1... GO!
        startCountdown {
            self.countdownFinished.send(())    // 🔔 game bắt đầu
        }
    }
}
```

```
playerInput:       ──tap──swipe──tap────tap──swipe──jump──
countdown:         ──3──2──1──🔔GO!─────────────────────
                               ↑ trigger

output:            ──────────────────tap──swipe──jump──
                    bỏ tap,swipe,tap  ↑ từ đây cho qua
```

---

## 8. So sánh với operators tương tự

### `drop(untilOutputFrom:)` vs `drop(while:)`

```swift
// drop(while:) — bỏ DỰA TRÊN VALUE của chính upstream
[1, 2, 5, 3, 6].publisher
    .drop(while: { $0 < 4 })
    .sink { print($0) }
// 5, 3, 6 (bỏ 1, 2 vì < 4; gặp 5 >= 4 → mở cổng; 3 VẪN đi qua)

// drop(untilOutputFrom:) — bỏ DỰA TRÊN PUBLISHER KHÁC
dataStream
    .drop(untilOutputFrom: trigger)
// Bỏ value không phụ thuộc vào value đó là gì, mà phụ thuộc vào trigger
```

```
drop(while:):            Điều kiện dựa trên VALUE      → self-controlled
drop(untilOutputFrom:):  Điều kiện dựa trên PUBLISHER KHÁC → external signal
```

### `drop(untilOutputFrom:)` vs `prefix(untilOutputFrom:)`

**Ngược nhau hoàn toàn:**

```swift
let data = PassthroughSubject<String, Never>()
let signal = PassthroughSubject<Void, Never>()

// drop(untilOutputFrom:) — BỎ trước signal, LẤY sau signal
data.drop(untilOutputFrom: signal)
// data:   ──A──B──🔔──C──D──
// output: ────────────C──D──

// prefix(untilOutputFrom:) — LẤY trước signal, BỎ sau signal (+ complete)
data.prefix(untilOutputFrom: signal)
// data:   ──A──B──🔔──C──D──
// output: ──A──B──|
//                  ↑ complete khi signal emit
```

```
              TRƯỚC signal    SAU signal
              ─────────────   ──────────
drop:         BỎ ❌            LẤY ✅
prefix:       LẤY ✅           BỎ + COMPLETE ❌|
```

### Bảng so sánh họ drop

```
Operator                    Bỏ dựa trên           Mở cổng khi
────────                    ───────────            ──────────
dropFirst(N)                Số lượng (N đầu tiên)  Sau N values
drop(while:)                Giá trị value          Điều kiện false lần đầu
drop(untilOutputFrom:)      Publisher khác          Publisher khác emit
```

```swift
// dropFirst(2): bỏ 2 value đầu
[1, 2, 3, 4, 5].publisher.dropFirst(2)
// → 3, 4, 5

// drop(while:): bỏ while điều kiện true
[1, 2, 5, 3, 6].publisher.drop(while: { $0 < 4 })
// → 5, 3, 6

// drop(untilOutputFrom:): bỏ cho đến khi publisher khác emit
data.drop(untilOutputFrom: trigger)
// → values sau trigger
```

---

## 9. Failure type phải khớp

```swift
let data = PassthroughSubject<String, MyError>()    // Failure = MyError
let trigger = PassthroughSubject<Void, Never>()     // Failure = Never

// ❌ Compile error: MyError ≠ Never
data.drop(untilOutputFrom: trigger)

// ✅ Giải pháp 1: nâng trigger Failure
let triggerWithError = trigger.setFailureType(to: MyError.self)
data.drop(untilOutputFrom: triggerWithError)

// ✅ Giải pháp 2: hạ upstream Failure
data.catch { _ in Empty<String, Never>() }
    .drop(untilOutputFrom: trigger)

// ✅ Giải pháp 3: cả hai về Error chung
data.mapError { $0 as Error }
    .drop(untilOutputFrom: trigger.setFailureType(to: Error.self))
```

---

## 10. Sai lầm thường gặp

### ❌ Trigger không bao giờ emit → cổng không bao giờ mở

```swift
let trigger = PassthroughSubject<Void, Never>()

dataStream
    .drop(untilOutputFrom: trigger)
    .sink { print($0) }
    .store(in: &cancellables)

// Quên gọi trigger.send(()) → không value nào đi qua
// ← Subscription sống nhưng sink KHÔNG BAO GIỜ nhận value
```

### ❌ Trigger emit trước subscribe

```swift
let trigger = CurrentValueSubject<Void, Never>(())
// ↑ CurrentValueSubject emit initial value ngay

dataStream
    .drop(untilOutputFrom: trigger)
    // ← trigger ĐÃ emit (initial value) → cổng MỞ NGAY
    // ← drop không bỏ gì cả — giống như không có drop
    .sink { print($0) }
```

### ❌ Nhầm: cổng đóng lại khi trigger emit thêm

```swift
// Cổng MỞ VĨNH VIỄN sau trigger lần đầu
// trigger.send() lần 2, 3... KHÔNG đóng cổng lại
// Nếu cần "toggle" → dùng logic khác (combineLatest + filter)
```

### ❌ Quên Failure type phải khớp

```swift
let data: AnyPublisher<String, URLError>
let trigger: AnyPublisher<Void, Never>

// ❌ URLError ≠ Never
data.drop(untilOutputFrom: trigger)

// ✅ setFailureType
data.drop(untilOutputFrom: trigger.setFailureType(to: URLError.self))
```

---

## 11. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Bỏ tất cả value cho đến khi publisher khác (trigger) emit lần đầu |
| **Cú pháp** | `.drop(untilOutputFrom: triggerPublisher)` |
| **Cổng mở** | Khi trigger emit **value đầu tiên** — mở **vĩnh viễn** |
| **Sau khi mở** | Mọi value upstream đi qua bình thường, trigger bị cancel |
| **Trigger value** | **Không quan trọng** — chỉ cần emit gì đó, value bị bỏ qua |
| **Failure** | Upstream và trigger phải **cùng Failure type** |
| **Upstream complete trước trigger** | Forward `.finished`, không emit value |
| **Trigger fail** | Pipeline fail |
| **vs drop(while:)** | `drop(while:)`: điều kiện dựa trên value. `drop(untilOutputFrom:)`: tín hiệu từ publisher khác |
| **vs prefix(untilOutputFrom:)** | Ngược nhau: drop bỏ trước signal, prefix lấy trước signal |
| **Dùng khi** | Đợi auth, đợi calibration, đợi view ready, game countdown, đợi config load |

----

`drop(untilOutputFrom:)` hoạt động như **cánh cổng** được mở bởi publisher khác, Huy. Ba điểm cốt lõi:

**Cổng mở bởi tín hiệu bên ngoài.** Khác với `drop(while:)` (điều kiện dựa trên value), `drop(untilOutputFrom:)` bỏ value dựa trên **publisher khác emit**. Trigger chỉ cần emit 1 value bất kỳ (value gì không quan trọng, chỉ là tín hiệu) → cổng mở **vĩnh viễn**, trigger bị cancel. Không có cách đóng lại.

**Đối xứng hoàn toàn với `prefix(untilOutputFrom:)`:** `drop` bỏ TRƯỚC signal + lấy SAU signal. `prefix` lấy TRƯỚC signal + complete SAU signal. Hai operator là "bản ngược" của nhau — cùng trigger nhưng giữ phần ngược lại.

**Ứng dụng thực tế phổ biến nhất:** đợi authentication xong rồi mới xử lý data stream, đợi calibration/initialization hoàn thành, đợi view fully loaded trước khi xử lý events, game countdown (bỏ player input trước khi "GO!"). Pattern chung: có một stream data liên tục emit nhưng cần "gate" nó cho đến khi hệ thống sẵn sàng.

**Lưu ý quan trọng:** Failure type của trigger và upstream **phải khớp**. Trigger `Never` + upstream `MyError` → compile error → dùng `.setFailureType(to:)` trên trigger để khớp. Và nếu trigger **không bao giờ emit** → cổng không bao giờ mở → sink không bao giờ nhận value — im lặng, không warning.
