# Combine: `Merge` — Giải thích chi tiết

## 1. Bản chất — Gộp nhiều stream thành một

`Merge` lấy **nhiều publisher cùng Output type** và gộp tất cả value vào **một stream duy nhất**. Value nào emit trước → đến trước, không biến đổi, không ghép cặp, không chờ đợi — chỉ **interleave theo thời gian**.

```
Publisher A: ──1─────3─────5──|
Publisher B: ────2─────4────────|
Merge:       ──1──2──3──4──5────|
               ↑  ↑  ↑  ↑  ↑
               A  B  A  B  A    (ai emit trước đến trước)
```

Hình dung: nhiều dòng suối nhỏ chảy vào **một dòng sông chung**. Nước (value) từ suối nào đến trước thì chảy qua trước.

---

## 2. Yêu cầu — Cùng Output type VÀ cùng Failure type

```swift
// ✅ Cùng Output (Int) + cùng Failure (Never)
let a = [1, 3, 5].publisher          // <Int, Never>
let b = [2, 4, 6].publisher          // <Int, Never>
a.merge(with: b)                     // <Int, Never> ✅

// ❌ Output KHÁC nhau → compile error
let names = ["A", "B"].publisher     // <String, Never>
let numbers = [1, 2].publisher       // <Int, Never>
names.merge(with: numbers)           // ❌ String ≠ Int

// ❌ Failure KHÁC nhau → compile error
let pubA: AnyPublisher<Int, URLError>       // <Int, URLError>
let pubB: AnyPublisher<Int, DecodingError>  // <Int, DecodingError>
pubA.merge(with: pubB)                      // ❌ URLError ≠ DecodingError

// ✅ Chuyển về cùng Failure trước khi merge
let pubA2 = pubA.mapError { $0 as Error }  // <Int, Error>
let pubB2 = pubB.mapError { $0 as Error }  // <Int, Error>
pubA2.merge(with: pubB2)                   // ✅
```

**So sánh với CombineLatest/Zip:**

```
Merge:          yêu cầu CÙNG Output type → Output giữ nguyên
CombineLatest:  Output có thể KHÁC nhau  → Output là tuple (A, B)
Zip:            Output có thể KHÁC nhau  → Output là tuple (A, B)
```

---

## 3. Các cách sử dụng Merge

### 3.1 Operator `.merge(with:)` — Chain trên publisher

```swift
// Merge 2
pubA.merge(with: pubB)

// Merge 3 (chain)
pubA.merge(with: pubB)
    .merge(with: pubC)

// Merge 4 (chain)
pubA.merge(with: pubB)
    .merge(with: pubC)
    .merge(with: pubD)
```

### 3.2 `Publishers.Merge` — Static type

```swift
// Merge2
Publishers.Merge(pubA, pubB)

// Merge3
Publishers.Merge3(pubA, pubB, pubC)

// Merge4, Merge5, Merge6, Merge7, Merge8
Publishers.Merge4(pubA, pubB, pubC, pubD)
Publishers.Merge8(p1, p2, p3, p4, p5, p6, p7, p8)
```

### 3.3 `Publishers.MergeMany` — Số lượng động (array)

```swift
// Từ variadic
Publishers.MergeMany(pubA, pubB, pubC, pubD, pubE, pubF)

// Từ array — quan trọng khi số lượng publisher không biết trước
let publishers: [AnyPublisher<Event, Never>] = buildPublishers()
Publishers.MergeMany(publishers)
    .sink { event in handle(event) }
    .store(in: &cancellables)
```

---

## 4. Minh hoạ chi tiết từng bước

```swift
let a = PassthroughSubject<String, Never>()
let b = PassthroughSubject<String, Never>()
let c = PassthroughSubject<String, Never>()

a.merge(with: b).merge(with: c)
    .sink { print($0) }
    .store(in: &cancellables)
```

```
Bước 1: a.send("A1")
  → merge nhận "A1" từ a → forward ngay
  Output: "A1" ✅

Bước 2: b.send("B1")
  → merge nhận "B1" từ b → forward ngay
  Output: "B1" ✅

Bước 3: c.send("C1")
  → merge nhận "C1" từ c → forward ngay
  Output: "C1" ✅

Bước 4: a.send("A2")
  Output: "A2" ✅

Bước 5: b.send("B2")
  Output: "B2" ✅

Timeline:
a:     ──"A1"──────────"A2"──────
b:     ────────"B1"──────────"B2"
c:     ──────────────"C1"────────
merge: ──"A1"──"B1"──"C1"──"A2"──"B2"──
```

**Không chờ đợi, không ghép cặp, không giữ latest** — chỉ forward mọi thứ theo thứ tự thời gian.

---

## 5. Completion Behavior

### Quy tắc

```
Merge FINISHED khi:
  → TẤT CẢ upstream publishers đã finished
  (một publisher finished, các publisher khác vẫn tiếp tục)

Merge FAIL khi:
  → BẤT KỲ upstream publisher nào fail
  → Fail NGAY, cancel tất cả publisher còn lại
```

### Minh hoạ — Finished

```swift
let a = PassthroughSubject<Int, Never>()
let b = PassthroughSubject<Int, Never>()

a.merge(with: b)
    .sink(
        receiveCompletion: { print("Done: \($0)") },
        receiveValue: { print($0) }
    )
    .store(in: &cancellables)

a.send(1)                          // 1
b.send(2)                          // 2
a.send(completion: .finished)      // a xong, nhưng b chưa → chưa complete
b.send(3)                          // 3 ✅ (b vẫn active)
b.send(completion: .finished)      // b cũng xong → "Done: finished"
```

```
a:     ──1────────|
b:     ────2──────────3──|
merge: ──1──2─────────3──|
                          ↑ complete khi CẢ HAI finished
```

### Minh hoạ — Failure

```swift
let a = PassthroughSubject<Int, MyError>()
let b = PassthroughSubject<Int, MyError>()

a.merge(with: b)
    .sink(
        receiveCompletion: { print("Done: \($0)") },
        receiveValue: { print($0) }
    )
    .store(in: &cancellables)

a.send(1)                                    // 1
b.send(2)                                    // 2
a.send(completion: .failure(.networkError))   // "Done: failure(networkError)"
b.send(3)                                    // ❌ Pipeline đã chết
```

---

## 6. Ứng dụng thực tế

### 6.1 Gộp nhiều nguồn Event cùng type

```swift
enum AppEvent {
    case userTapped(String)
    case notificationReceived(String)
    case deepLinkOpened(URL)
    case timerFired
}

class EventBus: ObservableObject {
    @Published private(set) var lastEvent: AppEvent?
    private var cancellables = Set<AnyCancellable>()
    
    // Nhiều nguồn event khác nhau, cùng type AppEvent
    let userActions = PassthroughSubject<AppEvent, Never>()
    let systemNotifications = PassthroughSubject<AppEvent, Never>()
    let deepLinks = PassthroughSubject<AppEvent, Never>()
    let timerEvents = PassthroughSubject<AppEvent, Never>()
    
    init() {
        // Merge tất cả vào 1 stream duy nhất
        Publishers.Merge4(userActions, systemNotifications, deepLinks, timerEvents)
            .sink { [weak self] event in
                self?.lastEvent = event
                self?.routeEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func routeEvent(_ event: AppEvent) {
        switch event {
        case .userTapped(let id):       analytics.track("tap", id: id)
        case .notificationReceived(let payload): handleNotification(payload)
        case .deepLinkOpened(let url):  router.navigate(to: url)
        case .timerFired:               refreshData()
        }
    }
}
```

### 6.2 Nhiều NotificationCenter events

```swift
class AppLifecycleObserver: ObservableObject {
    @Published private(set) var lifecycleEvent: String = "launched"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let didBecomeActive = NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .map { _ in "active" }
        
        let didEnterBackground = NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .map { _ in "background" }
        
        let willTerminate = NotificationCenter.default
            .publisher(for: UIApplication.willTerminateNotification)
            .map { _ in "terminating" }
        
        // Merge: lắng nghe TẤT CẢ lifecycle events
        didBecomeActive
            .merge(with: didEnterBackground)
            .merge(with: willTerminate)
            .sink { [weak self] state in
                self?.lifecycleEvent = state
                print("App is now: \(state)")
            }
            .store(in: &cancellables)
    }
}
```

```
didBecomeActive:     ──"active"─────────────"active"──
didEnterBackground:  ────────────"background"─────────
willTerminate:       ─────────────────────────────────
merge:               ──"active"──"background"──"active"──
```

### 6.3 Refresh từ nhiều trigger

```swift
class FeedViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Nhiều lý do để refresh — tất cả cùng type Void
    let pullToRefresh = PassthroughSubject<Void, Never>()
    let backgroundRefreshTrigger = PassthroughSubject<Void, Never>()
    
    init(api: FeedAPI) {
        let appBecameActive = NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .map { _ in () }
        
        let periodicRefresh = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .map { _ in () }
        
        // Merge tất cả trigger thành 1 stream "cần refresh"
        pullToRefresh
            .merge(with: backgroundRefreshTrigger)
            .merge(with: appBecameActive)
            .merge(with: periodicRefresh)
            .throttle(for: .seconds(10), scheduler: RunLoop.main, latest: false)
            // ↑ tránh refresh quá thường xuyên (tối đa 1 lần / 10 giây)
            .flatMap { _ in
                api.fetchFeed()
                    .catch { _ in Just([Post]()) }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] posts in
                self?.posts = posts
            }
            .store(in: &cancellables)
    }
}
```

```
pullToRefresh:          ──()────────────────()──
appBecameActive:        ────────()──────────────
periodicRefresh(300s):  ────────────────()──────
merge:                  ──()────()──────()──()──
throttle(10s):          ──()────()──────()──────  (()() gần nhau → chỉ lấy 1)
flatMap → API:          ──[fetch]─[fetch]─[fetch]──
```

### 6.4 Nhiều data source cho cùng một list

```swift
class MessageViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(localDB: LocalDatabase, webSocket: WebSocketService, pushService: PushService) {
        let localMessages = localDB.observeMessages()       // <Message, Never>
        let wsMessages = webSocket.incomingMessages()        // <Message, Never>
        let pushMessages = pushService.messageNotifications  // <Message, Never>
        
        // Merge: message từ BẤT KỲ nguồn nào đều hiển thị
        Publishers.Merge3(localMessages, wsMessages, pushMessages)
            .scan([Message]()) { accumulated, newMessage in
                var updated = accumulated
                if !updated.contains(where: { $0.id == newMessage.id }) {
                    updated.append(newMessage)
                }
                return updated.sorted { $0.timestamp > $1.timestamp }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$messages)
    }
}
```

### 6.5 MergeMany — Download nhiều file song song

```swift
func downloadAllFiles(urls: [URL]) -> AnyPublisher<DownloadResult, Never> {
    let publishers = urls.map { url in
        URLSession.shared.dataTaskPublisher(for: url)
            .map { data, _ in DownloadResult.success(url: url, data: data) }
            .catch { error in Just(DownloadResult.failure(url: url, error: error)) }
            .eraseToAnyPublisher()
    }
    
    // MergeMany: tất cả download chạy SONG SONG
    // Kết quả nào xong trước → emit trước
    return Publishers.MergeMany(publishers)
        .eraseToAnyPublisher()
}

// Sử dụng
downloadAllFiles(urls: imageURLs)
    .sink { result in
        switch result {
        case .success(let url, let data):
            print("✅ Downloaded: \(url)")
            saveToCache(url: url, data: data)
        case .failure(let url, let error):
            print("❌ Failed: \(url) - \(error)")
        }
    }
    .store(in: &cancellables)
```

```
URL1: ──────────────result1──
URL2: ──────result2──────────
URL3: ──────────────────result3──
merge: ─────result2──result1──result3──
              ↑ ai xong trước đến trước
```

### 6.6 Merge input events trong ViewModel

```swift
class CounterViewModel: ObservableObject {
    @Published private(set) var count = 0
    private var cancellables = Set<AnyCancellable>()
    
    // Nhiều cách thay đổi count — tất cả là Int offset
    let incrementTap = PassthroughSubject<Int, Never>()      // +1
    let decrementTap = PassthroughSubject<Int, Never>()      // -1
    let resetTap = PassthroughSubject<Int, Never>()           // set to 0
    let externalUpdate = PassthroughSubject<Int, Never>()     // from server
    
    init() {
        Publishers.Merge4(incrementTap, decrementTap, resetTap, externalUpdate)
            .scan(0) { current, change in current + change }
            .assign(to: &$count)
    }
}

// View
Button("+") { vm.incrementTap.send(1) }
Button("-") { vm.decrementTap.send(-1) }
Button("Reset") { vm.resetTap.send(-vm.count) }
```

---

## 7. Merge vs CombineLatest vs Zip — Cheat Sheet trực quan

```swift
let a = PassthroughSubject<Int, Never>()
let b = PassthroughSubject<Int, Never>()

// Cùng sequence event:
a.send(1)
b.send(10)
a.send(2)
b.send(20)
```

```
                    Merge           CombineLatest         Zip
                    ─────           ─────────────         ───
Output type         Int             (Int, Int)            (Int, Int)

a.send(1):          1               (chờ b...)            (chờ b...)
b.send(10):         10              (1, 10)               (1, 10)
a.send(2):          2               (2, 10)               (chờ b...)
b.send(20):         20              (2, 20)               (2, 20)

Tổng emit:          4               3                     2
Behaviour:          Forward tất cả  Combo latest mỗi      Ghép cặp 1-1
                    theo thời gian  khi ai đổi            tuần tự
```

### Quy tắc chọn

```
"Gộp nhiều nguồn event/data CÙNG TYPE thành 1 stream"
  → Merge ✅

"Kết hợp STATE từ nhiều nguồn, re-evaluate khi bất kỳ ai thay đổi"
  → CombineLatest ✅

"Đợi KẾT QUẢ từ nhiều nguồn, ghép cặp 1-1"
  → Zip ✅
```

---

## 8. Kết hợp Merge với các Operator khác

### + `map` trước merge: chuyển về cùng type

```swift
// Hai publisher khác Output type → map về cùng type → merge
let textChanges = textField.publisher      // <String, Never>
    .map { Event.textChanged($0) }         // <Event, Never>

let buttonTaps = button.tapPublisher       // <Void, Never>
    .map { Event.buttonTapped }            // <Event, Never>

textChanges.merge(with: buttonTaps)        // <Event, Never> ✅
    .sink { event in handle(event) }
```

### + `throttle` / `debounce` sau merge: kiểm soát tần suất

```swift
// Nhiều trigger → merge → throttle tránh spam
triggerA.merge(with: triggerB).merge(with: triggerC)
    .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: false)
    .flatMap { _ in api.refresh() }
    .sink { ... }
```

### + `scan` sau merge: accumulate từ nhiều nguồn

```swift
// Merge các event → scan accumulate state
let deposits = PassthroughSubject<Double, Never>()
let withdrawals = PassthroughSubject<Double, Never>()

let depositStream = deposits.map { +$0 }        // dương
let withdrawalStream = withdrawals.map { -$0 }   // âm

depositStream.merge(with: withdrawalStream)
    .scan(1000.0) { balance, transaction in balance + transaction }
    .sink { balance in print("Balance: $\(balance)") }
    .store(in: &cancellables)

deposits.send(500)       // Balance: $1500
withdrawals.send(200)    // Balance: $1300
deposits.send(100)       // Balance: $1400
```

### + `removeDuplicates` sau merge: loại trùng

```swift
// Nhiều nguồn có thể emit cùng value → loại trùng liên tiếp
sourceA.merge(with: sourceB)
    .removeDuplicates()
    .sink { ... }
```

### + `filter` sau merge: lọc

```swift
// Merge tất cả notification → chỉ giữ loại quan trọng
allNotifications
    .merge(with: pushNotifications)
    .filter { $0.priority == .high }
    .sink { notification in showAlert(notification) }
```

---

## 9. Sai lầm thường gặp

### ❌ Sai lầm 1: Merge publishers khác Output type

```swift
let names = PassthroughSubject<String, Never>()
let ages = PassthroughSubject<Int, Never>()

// ❌ Compile error: String ≠ Int
names.merge(with: ages)

// ✅ Giải pháp 1: Map về cùng type
names.map { $0 as Any }.merge(with: ages.map { $0 as Any })
// ⚠️ Mất type safety

// ✅ Giải pháp 2: Dùng enum wrapper
enum FormEvent {
    case nameChanged(String)
    case ageChanged(Int)
}
names.map { FormEvent.nameChanged($0) }
    .merge(with: ages.map { FormEvent.ageChanged($0) })
    .sink { event in
        switch event {
        case .nameChanged(let name): print(name)
        case .ageChanged(let age): print(age)
        }
    }
```

### ❌ Sai lầm 2: Nhầm Merge với CombineLatest

```swift
// Muốn: validate form dựa trên email VÀ password
// ❌ Merge — nhận từng String riêng lẻ, không biết là email hay password
$email.merge(with: $password)
    .sink { value in
        // value là String, nhưng là email hay password?
        // Không biết! Không thể validate cả hai
    }

// ✅ CombineLatest — nhận TUPLE (email, password) cùng lúc
$email.combineLatest($password)
    .sink { email, password in
        canSubmit = email.contains("@") && password.count >= 8
    }
```

### ❌ Sai lầm 3: Quên xử lý Failure type khác nhau

```swift
let apiA: AnyPublisher<Data, URLError>
let apiB: AnyPublisher<Data, DecodingError>

// ❌ Compile error: Failure types khác nhau
apiA.merge(with: apiB)

// ✅ Chuyển về cùng Error type
apiA.mapError { $0 as Error }
    .merge(with: apiB.mapError { $0 as Error })
// Hoặc
apiA.mapError { AppError.network($0) }
    .merge(with: apiB.mapError { AppError.decoding($0) })
```

---

## 10. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Gộp nhiều publisher **cùng type** thành 1 stream |
| **Output?** | Giữ nguyên Output type (không phải tuple) |
| **Yêu cầu?** | Tất cả publisher phải cùng `Output` VÀ cùng `Failure` |
| **Behavior?** | Forward value theo thứ tự thời gian, không chờ đợi, không ghép cặp |
| **Chờ đợi?** | ❌ Không — emit ngay khi bất kỳ publisher nào emit |
| **Complete?** | Khi **TẤT CẢ** upstream finished |
| **Fail?** | Khi **BẤT KỲ** upstream fail → fail ngay |
| **Số lượng?** | Merge (2), Merge3–Merge8, MergeMany (array/dynamic) |
| **Dùng khi?** | Gộp events, nhiều trigger refresh, nhiều data source cùng type, multi-input |
| **Khác CombineLatest?** | Merge: forward riêng lẻ, cùng type. CombineLatest: combo tuple, khác type OK |
| **Khác Zip?** | Merge: không ghép cặp. Zip: ghép cặp 1-1, đợi cả hai |

----

`Merge` là operator đơn giản nhất trong bộ ba Combining (Merge, CombineLatest, Zip), Huy. Nó chỉ làm đúng một việc: **gộp nhiều stream cùng type thành một stream**, forward value theo thứ tự thời gian.

**Khác biệt cốt lõi với CombineLatest và Zip:**

Merge **không ghép cặp, không giữ latest, không chờ đợi** — value nào đến trước thì qua trước. Output giữ nguyên type (Int → Int), không phải tuple. Đổi lại, yêu cầu tất cả publisher phải **cùng Output type và cùng Failure type**.

CombineLatest giữ latest value, emit tuple mỗi khi ai đổi. Zip ghép cặp 1-1. Merge chỉ forward riêng lẻ.

**Ứng dụng phổ biến nhất** là gộp nhiều nguồn event/trigger: pull-to-refresh + timer + app-became-active + push notification → merge tất cả thành 1 stream "cần refresh" → `throttle` tránh spam → `flatMap` gọi API. Pattern này rất phổ biến trong ViewModel.

**Tip quan trọng:** Khi hai publisher có Output type khác nhau, dùng `.map` chuyển về cùng type (thường qua enum wrapper) trước khi merge — giữ được type safety thay vì cast sang `Any`.
