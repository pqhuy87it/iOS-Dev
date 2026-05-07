# Combine: Tất cả Operators — Giải thích chi tiết

## 1. Operator là gì?

Operator là **mắt xích trung gian** trong pipeline — vừa là Subscriber (nhận từ upstream) vừa là Publisher (phát cho downstream). Mỗi operator có thể thay đổi `Output`, `Failure`, số lượng value, hoặc timing.

```
Publisher ──▶ Operator ──▶ Operator ──▶ Operator ──▶ Subscriber
              (biến đổi)   (lọc)        (timing)     (tiêu thụ)
```

## Phân loại tổng thể

```
Operators
│
├── 1. Transforming     — Biến đổi value
├── 2. Filtering        — Lọc, chọn value
├── 3. Combining        — Kết hợp nhiều publisher
├── 4. Timing           — Kiểm soát thời gian
├── 5. Sequence         — Thao tác trên thứ tự
├── 6. Error Handling   — Xử lý lỗi
├── 7. Scheduling       — Kiểm soát thread
├── 8. Type Erasure     — Giấu type
├── 9. Side Effects     — Tác dụng phụ
└── 10. Matching        — Kiểm tra điều kiện
```

---

# NHÓM 1: TRANSFORMING OPERATORS — Biến đổi value

## 1.1 `map` — Biến đổi từng value

```swift
[1, 2, 3].publisher
    .map { $0 * 10 }
    .sink { print($0) }
// 10, 20, 30
```

```
Input:  ──1──2──3──|
map:    ──10─20─30─|
```

Biến thể với KeyPath — gọn hơn closure:

```swift
struct User { let name: String; let age: Int }

[User(name: "Huy", age: 25)].publisher
    .map(\.name)           // tương đương .map { $0.name }
    .sink { print($0) }
// "Huy"

// Multi-keypath (tối đa 3)
URLSession.shared.dataTaskPublisher(for: url)
    .map(\.data, \.response)
// tương đương .map { ($0.data, $0.response) }
```

## 1.2 `tryMap` — map có thể throw

```swift
["1", "2", "abc", "4"].publisher
    .tryMap { str -> Int in
        guard let num = Int(str) else {
            throw ParseError.invalidNumber(str)
        }
        return num
    }
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
// 1, 2, failure(ParseError.invalidNumber("abc"))
// ← 4 không được emit vì pipeline đã fail
```

**⚠️ `tryMap` nới Failure thành `Error` (protocol gốc).** Dùng `.mapError` sau nếu cần concrete error type.

## 1.3 `compactMap` / `tryCompactMap` — Transform + loại bỏ nil

```swift
["1", "2", "abc", "4"].publisher
    .compactMap { Int($0) }       // Int("abc") = nil → bị loại
    .sink { print($0) }
// 1, 2, 4
```

```
Input:       ──"1"──"2"──"abc"──"4"──|
compactMap:  ──1────2───────────4────|
                         ↑ nil → bỏ
```

```swift
// Ứng dụng: parse JSON an toàn
notificationPublisher
    .compactMap { $0.userInfo?["payload"] as? Data }
    .compactMap { try? JSONDecoder().decode(Message.self, from: $0) }
    .sink { message in handleMessage(message) }
```

## 1.4 `flatMap` — Transform value thành publisher mới rồi merge

```swift
$userId
    .flatMap { id in
        api.fetchUser(id: id)      // mỗi id → publisher mới
    }
    .sink { user in print(user) }
```

```
$userId:   ──1─────────2──────────
flatMap:   ──[fetch(1)]─[fetch(2)]
output:    ──────User1───────User2
```

`flatMap(maxPublishers:)` giới hạn số inner publisher đồng thời:

```swift
urls.publisher
    .flatMap(maxPublishers: .max(3)) { url in
        downloadFile(url)     // tối đa 3 concurrent downloads
    }
```

## 1.5 `scan` — Accumulate (giống reduce nhưng phát từng bước)

```swift
[1, 2, 3, 4, 5].publisher
    .scan(0) { accumulated, value in accumulated + value }
    .sink { print($0) }
// 1, 3, 6, 10, 15
```

```
Input:  ──1──2──3──4───5──|
scan:   ──1──3──6──10──15─|
          ↑  ↑  ↑
         0+1 1+2 3+3  (running total)
```

```swift
// Ứng dụng: đếm số lần tap
buttonTapPublisher
    .scan(0) { count, _ in count + 1 }
    .sink { tapCount in print("Tapped \(tapCount) times") }
```

## 1.6 `reduce` — Gom tất cả thành 1 value cuối cùng

```swift
[1, 2, 3, 4, 5].publisher
    .reduce(0, +)
    .sink { print($0) }
// 15  (chỉ phát 1 value khi upstream complete)
```

```
Input:   ──1──2──3──4──5──|
reduce:  ─────────────────15──|
                           ↑ chỉ emit khi finished
```

**Khác `scan`:** `scan` emit mỗi bước, `reduce` chỉ emit kết quả cuối.

## 1.7 `replaceNil` — Thay nil bằng giá trị mặc định

```swift
[1, nil, 3, nil, 5].publisher
    .replaceNil(with: 0)
    .sink { print($0) }
// 1, 0, 3, 0, 5
```

## 1.8 `collect` — Gom value thành mảng

```swift
// Gom TẤT CẢ (đợi finished)
[1, 2, 3, 4, 5].publisher
    .collect()
    .sink { print($0) }
// [1, 2, 3, 4, 5]

// Gom theo batch
[1, 2, 3, 4, 5].publisher
    .collect(2)
    .sink { print($0) }
// [1, 2], [3, 4], [5]

// Gom theo thời gian
publisher
    .collect(.byTime(RunLoop.main, .seconds(1)))
// Mỗi giây gom values thành 1 mảng
```

---

# NHÓM 2: FILTERING OPERATORS — Lọc value

## 2.1 `filter` / `tryFilter` — Giữ value thoả điều kiện

```swift
(1...10).publisher
    .filter { $0.isMultiple(of: 3) }
    .sink { print($0) }
// 3, 6, 9
```

```
Input:   ──1──2──3──4──5──6──7──8──9──10──|
filter:  ─────────3────────6────────9─────|
```

## 2.2 `removeDuplicates` — Bỏ value trùng liên tiếp

```swift
[1, 1, 2, 2, 2, 3, 1].publisher
    .removeDuplicates()
    .sink { print($0) }
// 1, 2, 3, 1
// ↑ chỉ bỏ LIÊN TIẾP, 1 cuối vẫn giữ vì trước nó là 3
```

```
Input:            ──1──1──2──2──2──3──1──|
removeDuplicates: ──1─────2────────3──1──|
```

Custom comparison:

```swift
$user
    .removeDuplicates { prev, curr in
        prev.name == curr.name && prev.age == curr.age
    }
```

## 2.3 `first` / `last` — Lấy phần tử đầu/cuối

```swift
[1, 2, 3, 4, 5].publisher
    .first()                        // 1 rồi complete ngay (cancel upstream)
    
    .first(where: { $0 > 3 })      // 4 rồi complete

    .last()                         // 5 (đợi upstream complete mới phát)

    .last(where: { $0 < 4 })       // 3
```

```
Input:        ──1──2──3──4──5──|
first():      ──1──|                 (cancel upstream sau value đầu)
last():       ─────────────────5──|  (đợi finished mới emit)
```

## 2.4 `dropFirst` / `drop(while:)` / `drop(untilOutputFrom:)` — Bỏ đầu

```swift
[1, 2, 3, 4, 5].publisher
    .dropFirst(2)
    .sink { print($0) }
// 3, 4, 5

[1, 2, 6, 3, 5].publisher
    .drop(while: { $0 < 5 })    // bỏ CHO ĐẾN KHI điều kiện false
    .sink { print($0) }
// 6, 3, 5  (sau khi gặp 6 >= 5, lấy hết phần còn lại)
```

```
Input:        ──1──2──6──3──5──|
drop(<5):     ─────────6──3──5─|
                       ↑ 6>=5 → bắt đầu lấy, lấy hết kể cả 3<5
```

```swift
// drop(untilOutputFrom:) — bỏ cho đến khi publisher khác emit
let trigger = PassthroughSubject<Void, Never>()
let data = PassthroughSubject<Int, Never>()

data.drop(untilOutputFrom: trigger)
    .sink { print($0) }

data.send(1)         // ❌ bỏ (trigger chưa emit)
data.send(2)         // ❌ bỏ
trigger.send()       // ← mở cổng
data.send(3)         // ✅ 3
data.send(4)         // ✅ 4
```

## 2.5 `prefix` / `prefix(while:)` / `prefix(untilOutputFrom:)` — Lấy đầu

Ngược lại với `drop`:

```swift
[1, 2, 3, 4, 5].publisher
    .prefix(3)
    .sink { print($0) }
// 1, 2, 3 (cancel upstream sau 3 value)

[1, 2, 6, 3, 5].publisher
    .prefix(while: { $0 < 5 })
    .sink { print($0) }
// 1, 2 (gặp 6 >= 5 → complete ngay)
```

```
Input:          ──1──2──6──3──5──|
prefix(<5):     ──1──2──|
                         ↑ 6>=5 → complete, KHÔNG lấy gì thêm
```

```swift
// prefix(untilOutputFrom:) — lấy cho đến khi publisher khác emit
let cancel = PassthroughSubject<Void, Never>()

Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .prefix(untilOutputFrom: cancel)    // timer chạy cho đến khi cancel emit
    .sink { print($0) }
    .store(in: &cancellables)

// Sau 5 giây:
cancel.send()    // timer dừng
```

## 2.6 `output(at:)` / `output(in:)` — Lấy theo index

```swift
["A", "B", "C", "D", "E"].publisher
    .output(at: 2)
    .sink { print($0) }
// "C"

["A", "B", "C", "D", "E"].publisher
    .output(in: 1...3)
    .sink { print($0) }
// "B", "C", "D"
```

---

# NHÓM 3: COMBINING OPERATORS — Kết hợp Publisher

## 3.1 `merge` — Gộp nhiều stream cùng type

```swift
let pub1 = [1, 3, 5].publisher
let pub2 = [2, 4, 6].publisher

pub1.merge(with: pub2)
    .sink { print($0) }
// 1, 3, 5, 2, 4, 6  (thứ tự thực tế tuỳ timing)
```

```
pub1:  ──1──3──5──|
pub2:  ──2──4──6──|
merge: ──1──2──3──4──5──6──|   (interleave)
```

```swift
// Merge nhiều: MergeMany
Publishers.MergeMany(arrayOfPublishers)
    .sink { value in handle(value) }
```

## 3.2 `combineLatest` — Combo value MỚI NHẤT từ mỗi publisher

```swift
let name = PassthroughSubject<String, Never>()
let age = PassthroughSubject<Int, Never>()

name.combineLatest(age)
    .sink { print("\($0), \($1)") }

name.send("Huy")       // chờ age...
age.send(25)            // ✅ "Huy, 25"
age.send(26)            // ✅ "Huy, 26"  (name giữ "Huy")
name.send("John")       // ✅ "John, 26" (age giữ 26)
```

```
name:  ──"Huy"──────────"John"──
age:   ────────25──26───────────
out:   ────────(H,25)─(H,26)─(J,26)──
               ↑ phải đợi CẢ HAI có value đầu tiên
```

```swift
// Ứng dụng kinh điển: form validation
Publishers.CombineLatest3($email, $password, $confirmPassword)
    .map { email, pass, confirm in
        email.contains("@") && pass.count >= 8 && pass == confirm
    }
    .assign(to: &$canSubmit)
// CombineLatest, CombineLatest3, CombineLatest4 (tối đa 4 publisher)
```

## 3.3 `zip` — Ghép cặp 1-1

```swift
let letters = ["A", "B", "C"].publisher
let numbers = [1, 2, 3].publisher

letters.zip(numbers)
    .sink { print("\($0)\($1)") }
// "A1", "B2", "C3"
```

```
letters: ──A──B──C──|
numbers: ──1──2──3──|
zip:     ──(A,1)──(B,2)──(C,3)──|
```

**Zip vs CombineLatest:**

```
CombineLatest: emit mỗi khi EITHER thay đổi (dùng latest của other)
Zip:           emit chỉ khi CẢ HAI có value MỚI (ghép cặp tuần tự)
```

## 3.4 `switchToLatest` — Cancel publisher cũ, chỉ giữ mới nhất

```swift
$searchQuery
    .map { query in api.search(query) }    // Publisher<Publisher<[Item], Error>>
    .switchToLatest()                       // → Publisher<[Item], Error>
    .sink { results in ... }
```

```
query:   ──"S"──"Sw"──"Swift"──
map:     ──[req1]──[req2]──[req3]──
switch:  ──cancel1──cancel2──[req3 result]──
         ↑ chỉ giữ request mới nhất
```

## 3.5 `prepend` / `append` — Thêm value đầu/cuối

```swift
[3, 4, 5].publisher
    .prepend(1, 2)             // thêm trước
    .append(6, 7)              // thêm sau
    .sink { print($0) }
// 1, 2, 3, 4, 5, 6, 7

// Prepend/Append publisher khác
let cached = [1, 2].publisher
let fresh = [3, 4, 5].publisher

cached.append(fresh)
    .sink { print($0) }
// 1, 2, 3, 4, 5  (cached xong → fresh tiếp)
```

```
cached:  ──1──2──|
fresh:   ──────────3──4──5──|
append:  ──1──2──3──4──5──|
```

---

# NHÓM 4: TIMING OPERATORS — Kiểm soát thời gian

## 4.1 `debounce` — Đợi "yên lặng" rồi emit value cuối

```swift
$searchQuery
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .sink { query in search(query) }
```

```
Input:    ──S──Sw──Swi──Swift──────────────
debounce: ─────────────────────Swift───────
                               ↑ 300ms sau value cuối
```

Chỉ emit khi **không có value mới trong khoảng thời gian chỉ định**. Value trước đó bị bỏ qua.

```swift
// Ứng dụng: search, auto-save, resize handler
$documentContent
    .debounce(for: .seconds(2), scheduler: RunLoop.main)
    .sink { [weak self] content in
        self?.autoSave(content)    // save sau 2s ngừng gõ
    }
```

## 4.2 `throttle` — Lấy mẫu theo khoảng thời gian cố định

```swift
$scrollOffset
    .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
    .sink { offset in updateParallax(offset) }
```

```
Input:    ──1──2──3──4──5──6──7──8──9──
throttle: ──1───────4───────7──────────
              |100ms| |100ms|
              ↑ lấy 1 value mỗi 100ms
```

`latest: true` → lấy value **mới nhất** trong window. `latest: false` → lấy value **đầu tiên**.

**Debounce vs Throttle:**

```
debounce: "Đợi user NGỪNG rồi mới hành động"
           → search input, auto-save
           → Thời gian ĐỢI reset mỗi khi có value mới

throttle: "Hành động ĐỀU ĐẶN dù user liên tục input"
           → scroll handler, analytics logging
           → Thời gian cố định, không reset
```

## 4.3 `delay` — Trì hoãn mỗi value

```swift
publisher
    .delay(for: .seconds(2), scheduler: RunLoop.main)
    .sink { print($0) }
// Mỗi value bị trì hoãn 2 giây
```

```
Input:  ──A──B──C──|         (t=0, t=1, t=2)
delay:  ──────A──B──C──|     (t=2, t=3, t=4)
```

## 4.4 `timeout` — Giới hạn thời gian chờ

```swift
networkPublisher
    .timeout(.seconds(10), scheduler: RunLoop.main)
    .sink(
        receiveCompletion: { completion in
            // .finished nếu timeout (mặc định)
        },
        receiveValue: { data in ... }
    )

// Timeout với custom error
networkPublisher
    .timeout(.seconds(10), scheduler: RunLoop.main, customError: { .timedOut })
    .sink(...)
```

## 4.5 `measureInterval` — Đo khoảng cách giữa các value

```swift
publisher
    .measureInterval(using: RunLoop.main)
    .sink { interval in
        print("Time since last value: \(interval.magnitude) seconds")
    }
```

---

# NHÓM 5: SEQUENCE OPERATORS — Thao tác trên thứ tự

## 5.1 `min` / `max` — Tìm giá trị nhỏ/lớn nhất

```swift
[5, 2, 8, 1, 9].publisher
    .min()
    .sink { print($0) }
// 1 (đợi upstream complete)

[5, 2, 8, 1, 9].publisher
    .max()
    .sink { print($0) }
// 9
```

Custom comparison:

```swift
users.publisher
    .min(by: { $0.age < $1.age })
    .sink { print("Youngest: \($0.name)") }
```

## 5.2 `count` — Đếm số lượng value

```swift
[1, 2, 3, 4, 5].publisher
    .count()
    .sink { print($0) }
// 5 (đợi upstream complete)
```

## 5.3 `contains` / `allSatisfy` — Kiểm tra điều kiện

```swift
[1, 2, 3, 4, 5].publisher
    .contains(3)
    .sink { print($0) }
// true (emit ngay khi tìm thấy, cancel upstream)

[2, 4, 6, 8].publisher
    .allSatisfy { $0.isMultiple(of: 2) }
    .sink { print($0) }
// true (đợi upstream complete mới biết chắc)
```

---

# NHÓM 6: ERROR HANDLING OPERATORS — Xử lý lỗi

## 6.1 `mapError` — Biến đổi Error type

```swift
urlSession.dataTaskPublisher(for: url)
    .mapError { urlError -> AppError in
        switch urlError.code {
        case .notConnectedToInternet: return .offline
        case .timedOut: return .timeout
        default: return .network(urlError)
        }
    }
```

```
Trước: <Data, URLError>
Sau:   <Data, AppError>
```

Dùng phổ biến sau `tryMap` để thu hẹp `Error` → concrete type:

```swift
.tryMap { ... }                              // Failure → Error (nới rộng)
.mapError { $0 as? MyError ?? .unknown }     // Error → MyError (thu hẹp)
```

## 6.2 `replaceError` — Thay error bằng giá trị mặc định

```swift
api.fetchUsers()                         // <[User], Error>
    .replaceError(with: [])              // <[User], Never>  ← Failure thành Never
    .sink(receiveValue: { users in ... })
```

```
Input:   ──User1──✗(error)
replace: ──User1──[]──|
                  ↑ error → default value → finished
```

## 6.3 `catch` — Thay error bằng publisher khác

```swift
api.fetchUsers()
    .catch { error -> AnyPublisher<[User], Never> in
        print("Error: \(error), using cache")
        return cacheService.getCachedUsers()    // fallback publisher
    }
    .sink(receiveValue: { users in ... })
```

```
Input:   ──✗(error)
catch:   ──[switch to cache publisher]──CachedUser1──CachedUser2──|
```

**`catch` kết thúc subscription gốc.** Sau khi catch, chỉ còn fallback publisher.

## 6.4 `tryCatch` — catch có thể throw

```swift
api.fetchUsers()
    .tryCatch { error -> AnyPublisher<[User], Error> in
        guard error is NetworkError else { throw error }  // throw lại nếu không phải network
        return cacheService.getCachedUsers()
    }
```

## 6.5 `retry` — Tự động thử lại khi fail

```swift
api.fetchData()
    .retry(3)         // thử tối đa 3 lần nữa (tổng 4 lần)
    .sink(
        receiveCompletion: { ... },  // fail sau 4 lần → nhận error
        receiveValue: { ... }
    )
```

```
Lần 1: ──✗(error)                → retry
Lần 2: ──✗(error)                → retry
Lần 3: ──✗(error)                → retry
Lần 4: ──✗(error)                → gửi error cho subscriber (hết retry)

HOẶC:
Lần 1: ──✗(error)                → retry
Lần 2: ──Data──|                  → thành công, dừng retry
```

```swift
// Kết hợp retry + delay
api.fetchData()
    .delay(for: .seconds(2), scheduler: RunLoop.main)   // đợi 2s giữa mỗi lần
    .retry(3)
    .sink(...)
```

## 6.6 `setFailureType` — Nâng Failure từ Never lên type cụ thể

```swift
Just("Hello")                                    // <String, Never>
    .setFailureType(to: MyError.self)            // <String, MyError>
    .tryMap { throw MyError.tooShort($0) }       // giờ mới throw được
```

Chỉ dùng được khi `Failure == Never`. Không thay đổi runtime behavior, chỉ thay đổi type ở compile-time.

## 6.7 `assertNoFailure` — Debug: crash nếu nhận error

```swift
publisher
    .assertNoFailure("Should never fail!")    // crash với message nếu error
    .sink(receiveValue: { ... })

// Dùng trong debug/test, KHÔNG dùng production
```

---

# NHÓM 7: SCHEDULING OPERATORS — Kiểm soát thread

## 7.1 `receive(on:)` — Chuyển VALUE delivery sang thread khác

```swift
URLSession.shared.dataTaskPublisher(for: url)
    .map(\.data)
    .decode(type: User.self, decoder: JSONDecoder())
    // ↑ tất cả chạy trên background thread
    .receive(on: DispatchQueue.main)
    // ↓ từ đây chuyển sang main thread
    .sink(receiveValue: { user in
        self.label.text = user.name    // ✅ main thread, UI safe
    })
```

```
Background thread:  ──fetch──map──decode──
                                         │ .receive(on: main)
Main thread:        ─────────────────────sink──
```

## 7.2 `subscribe(on:)` — Chuyển SUBSCRIPTION (upstream work) sang thread khác

```swift
heavyPublisher
    .subscribe(on: DispatchQueue.global(qos: .background))
    // ↑ upstream work chạy trên background
    .receive(on: DispatchQueue.main)
    // ↓ downstream delivery trên main
    .sink { result in updateUI(result) }
```

**`subscribe(on:)` vs `receive(on:)`:**

```
subscribe(on:): ảnh hưởng UPSTREAM — nơi publisher thực thi work
receive(on:):   ảnh hưởng DOWNSTREAM — nơi subscriber nhận value

                subscribe(on: background)     receive(on: main)
                        ↓                           ↓
Publisher ──────── [work on background] ──── [deliver on main] ──── Subscriber
```

---

# NHÓM 8: TYPE ERASURE

## 8.1 `eraseToAnyPublisher` — Giấu concrete type

```swift
func fetchUsers() -> AnyPublisher<[User], Error> {
    URLSession.shared.dataTaskPublisher(for: url)
        .map(\.data)
        .decode(type: [User].self, decoder: JSONDecoder())
        .eraseToAnyPublisher()
    //  ↑ concrete type dài → AnyPublisher đơn giản
}
```

## 8.2 `eraseToAnySubscriber` — Giấu subscriber type

```swift
// Ít dùng hơn, chủ yếu khi cần type-erase subscriber
let subscriber = AnySubscriber<Int, Never>(
    receiveSubscription: { $0.request(.unlimited) },
    receiveValue: { print($0); return .none },
    receiveCompletion: { _ in }
)
```

---

# NHÓM 9: SIDE EFFECTS — Tác dụng phụ (không thay đổi value)

## 9.1 `handleEvents` — Hook vào mọi lifecycle event

```swift
publisher
    .handleEvents(
        receiveSubscription: { sub in print("Subscribed") },
        receiveOutput: { value in print("Value: \(value)") },
        receiveCompletion: { comp in print("Completed: \(comp)") },
        receiveCancel: { print("Cancelled") },
        receiveRequest: { demand in print("Demand: \(demand)") }
    )
    .sink { ... }
```

Value đi qua **không thay đổi** — chỉ "quan sát". Dùng cho debug, logging, side effects:

```swift
$searchQuery
    .handleEvents(receiveOutput: { [weak self] _ in
        self?.isLoading = true          // side effect: bật loading
    })
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .flatMap { query in api.search(query) }
    .handleEvents(receiveOutput: { [weak self] _ in
        self?.isLoading = false         // side effect: tắt loading
    })
    .assign(to: &$results)
```

## 9.2 `print` — Debug: in mọi event ra console

```swift
[1, 2, 3].publisher
    .print("DEBUG")
    .sink { _ in }

// Output:
// DEBUG: receive subscription: ([1, 2, 3])
// DEBUG: request unlimited
// DEBUG: receive value: (1)
// DEBUG: receive value: (2)
// DEBUG: receive value: (3)
// DEBUG: receive finished
```

## 9.3 `breakpoint` — Dừng debugger khi điều kiện thoả

```swift
publisher
    .breakpoint(receiveOutput: { value in
        value > 100    // Xcode dừng tại đây nếu value > 100
    })
```

---

# NHÓM 10: MATCHING OPERATORS — Kiểm tra điều kiện

## 10.1 `contains` / `contains(where:)`

```swift
[1, 2, 3, 4, 5].publisher
    .contains(3)                    // true (emit ngay, cancel upstream)
    .sink { print($0) }

[1, 2, 3].publisher
    .contains(where: { $0 > 10 })  // false (đợi finished mới biết)
    .sink { print($0) }
```

## 10.2 `allSatisfy`

```swift
[2, 4, 6].publisher
    .allSatisfy { $0.isMultiple(of: 2) }
    .sink { print($0) }
// true

[2, 4, 5].publisher
    .allSatisfy { $0.isMultiple(of: 2) }
    .sink { print($0) }
// false (emit ngay khi tìm thấy phần tử vi phạm)
```

---

# TỔNG HỢP: Ví dụ kết hợp thực tế

```swift
class ProductSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var category: Category = .all
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    
    private let api: ProductAPI
    
    init(api: ProductAPI = .shared) {
        self.api = api
        
        // CombineLatest: query + category → search khi EITHER thay đổi
        Publishers.CombineLatest($query, $category)
            // debounce: đợi user ngừng thay đổi
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            // removeDuplicates: bỏ qua nếu combo giống y hệt
            .removeDuplicates { prev, curr in
                prev.0 == curr.0 && prev.1 == curr.1
            }
            // handleEvents: side effect bật loading
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = true
                self?.error = nil
            })
            // filter: không search query rỗng
            .filter { !$0.0.trimmingCharacters(in: .whitespaces).isEmpty }
            // map → switchToLatest: cancel search cũ
            .map { [api] query, category in
                api.search(query: query, category: category)
                    .catch { error -> Just<[Product]> in
                        Just([])
                    }
            }
            .switchToLatest()
            // receive: về main thread
            .receive(on: DispatchQueue.main)
            // handleEvents: tắt loading
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = false
            })
            // assign: gán kết quả
            .assign(to: &$products)
    }
}
```

```
User gõ "iPhone" + chọn category "Electronics"

$query:           ──"i"──"iP"──"iPh"──"iPhone"──
$category:        ──"Electronics"────────────────
CombineLatest:    ──("i",Elec)──...──("iPhone",Elec)──
debounce(300ms):  ──────────────────────("iPhone",Elec)──
removeDuplicates: ──────────────────────("iPhone",Elec)──
handleEvents:     ──────────────────────isLoading=true──
filter(!empty):   ──────────────────────("iPhone",Elec)──
map→API:          ──────────────────────[search request]──
switchToLatest:   ──────────────────────[cancel old, keep new]──
receive(main):    ──────────────────────[Product1, Product2]──
handleEvents:     ──────────────────────isLoading=false──
assign:           ──────────────────────products = [...]──
```

---

# Bảng tham chiếu nhanh

| Operator | Nhóm | Input → Output | Đặc điểm |
|---|---|---|---|
| `map` | Transform | 1→1 | Biến đổi value |
| `compactMap` | Transform | 1→0/1 | map + loại nil |
| `flatMap` | Transform | 1→N (publisher) | Transform thành publisher, merge |
| `scan` | Transform | 1→1 | Accumulate, emit mỗi bước |
| `reduce` | Transform | N→1 | Accumulate, emit cuối |
| `collect` | Transform | N→1 array | Gom thành mảng |
| `filter` | Filter | 1→0/1 | Giữ value thoả điều kiện |
| `removeDuplicates` | Filter | 1→0/1 | Bỏ trùng liên tiếp |
| `first` / `last` | Filter | N→1 | Phần tử đầu/cuối |
| `dropFirst` | Filter | N→(N-k) | Bỏ k phần tử đầu |
| `prefix` | Filter | N→k | Lấy k phần tử đầu |
| `merge` | Combine | 2 stream→1 | Gộp cùng type |
| `combineLatest` | Combine | 2→tuple | Combo mới nhất |
| `zip` | Combine | 2→tuple | Ghép cặp 1-1 |
| `switchToLatest` | Combine | Pub\<Pub\>→Pub | Cancel cũ, giữ mới nhất |
| `debounce` | Timing | 1→0/1 | Đợi yên lặng |
| `throttle` | Timing | N→sampled | Lấy mẫu đều |
| `delay` | Timing | 1→1 | Trì hoãn |
| `timeout` | Timing | — | Giới hạn thời gian |
| `retry` | Error | — | Thử lại khi fail |
| `catch` | Error | Error→Pub | Thay error bằng publisher |
| `replaceError` | Error | Error→value | Thay error bằng default |
| `mapError` | Error | Error→Error | Biến đổi error type |
| `receive(on:)` | Schedule | — | Thread nhận value |
| `subscribe(on:)` | Schedule | — | Thread thực thi work |
| `handleEvents` | Side Effect | — | Hook lifecycle, không đổi value |
| `print` | Side Effect | — | Debug log |

---

Đây là bức tranh toàn cảnh về operators trong Combine, Huy. Tóm gọn theo nhóm quan trọng nhất:

**Transforming** — `map` (biến đổi 1-1), `compactMap` (biến đổi + loại nil), `flatMap` (biến thành publisher mới rồi merge), `scan` (accumulate phát từng bước), `collect` (gom thành mảng). Đây là nhóm dùng nhiều nhất.

**Filtering** — `filter`, `removeDuplicates` (bỏ trùng liên tiếp), `first`/`last`, `dropFirst`/`prefix`. Lưu ý `drop(while:)` vs `prefix(while:)` ngược nhau: drop bỏ đầu cho đến khi điều kiện false, prefix lấy đầu cho đến khi điều kiện false.

**Timing** — Cặp đôi quan trọng nhất: **`debounce`** (đợi user ngừng rồi mới hành động → search) vs **`throttle`** (hành động đều đặn theo interval → scroll handler). Hai cái hay bị nhầm nhưng behavior rất khác.

**Error Handling** — `retry` (thử lại), `catch` (thay bằng fallback publisher), `replaceError` (thay bằng default value), `mapError` (đổi error type). Pattern phổ biến: `tryMap` → `mapError` để thu hẹp `Error` về concrete type.

**Scheduling** — `receive(on:)` ảnh hưởng **downstream** (nơi subscriber nhận value), `subscribe(on:)` ảnh hưởng **upstream** (nơi publisher thực thi). Gần như mọi pipeline kết nối UI đều cần `.receive(on: DispatchQueue.main)` trước `sink`/`assign`.
