# Combine: `.first()` & `.first(where:)` — Giải thích chi tiết

## 1. Bản chất — Lấy value đầu tiên rồi DỪNG

`first()` và `first(where:)` là **filtering operators** — chúng lấy value đầu tiên (thoả điều kiện) rồi **ngay lập tức gửi `.finished` và cancel upstream**. Pipeline kết thúc sau đúng 1 value.

```
first():
Input:  ──1──2──3──4──5──|
Output: ──1──|
              ↑ emit 1, finished, CANCEL upstream
              (2, 3, 4, 5 không bao giờ được xử lý)

first(where: { $0 > 3 }):
Input:  ──1──2──3──4──5──|
Output: ──────────4──|
                     ↑ 4 là value ĐẦU TIÊN > 3
                       emit 4, finished, CANCEL upstream
```

Hình dung: đặt **bẫy** trên dòng suối — bắt con cá đầu tiên (thoả điều kiện) rồi **thu bẫy về**, không bắt thêm.

---

## 2. `.first()` — Value đầu tiên, không điều kiện

### Cú pháp

```swift
publisher.first()
// Lấy value đầu tiên upstream emit, rồi complete + cancel upstream
```

### Ví dụ cơ bản

```swift
[10, 20, 30, 40, 50].publisher
    .first()
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Value: 10
// Completion: finished
```

### Timeline chi tiết

```
Upstream:  ──10──20──30──40──50──|
first():   ──10──|
                  ↑ Ngay khi nhận 10:
                    1. Emit 10 cho downstream
                    2. Gửi .finished
                    3. Cancel subscription với upstream
                    4. Upstream DỪNG emit (20-50 không bao giờ phát)
```

### Type signature

```swift
// Input:  Publisher<Int, Never>
// Output: Publishers.First<Publisher<Int, Never>>
//         Output = Int (giữ nguyên)
//         Failure = Never (giữ nguyên)
//         Emit: đúng 1 value rồi complete
```

---

## 3. `.first(where:)` — Value đầu tiên thoả điều kiện

### Cú pháp

```swift
publisher.first(where: { value -> Bool in
    // return true → LẤY value này, complete
    // return false → BỎ QUA, chờ value tiếp
})
```

### Ví dụ cơ bản

```swift
[1, 2, 3, 4, 5, 6, 7, 8].publisher
    .first(where: { $0.isMultiple(of: 3) })
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Value: 3
// Completion: finished
```

### Timeline chi tiết

```
Upstream:         ──1──2──3──4──5──6──7──8──|
first(where: %3): ─────────3──|
                   ↑  ↑     ↑
                  skip skip  3 % 3 == 0 → MATCH!
                             emit 3, finished, cancel upstream
                             (4-8 không bao giờ được xử lý)
```

### Không tìm thấy → chỉ complete khi upstream complete

```swift
[1, 2, 3].publisher
    .first(where: { $0 > 10 })
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Completion: finished
// ← KHÔNG có value nào, chỉ completion
// ← Vì upstream complete mà không value nào > 10
```

```
Upstream:          ──1──2──3──|
first(where: >10): ──────────|
                   skip skip skip
                              ↑ upstream finished mà chưa match
                                → forward .finished, không emit value
```

---

## 4. `.tryFirst(where:)` — first(where:) có thể throw

```swift
publisher.tryFirst(where: { value -> Bool in
    // Có thể throw error
    guard isValid(value) else { throw ValidationError.invalid }
    return value > threshold
})
```

```swift
["1", "2", "abc", "4"].publisher
    .tryFirst(where: { str -> Bool in
        guard let num = Int(str) else {
            throw ParseError.notANumber(str)
        }
        return num > 3
    })
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Completion: failure(ParseError.notANumber("abc"))
// ← "1" → 1, 1 > 3 = false → skip
// ← "2" → 2, 2 > 3 = false → skip
// ← "abc" → throw! → pipeline fail
// ← "4" không được xử lý
```

**`tryFirst(where:)` nới Failure thành `Error`** — giống `tryMap`. Dùng `mapError` sau nếu cần concrete error type.

---

## 5. Cancel upstream — Đặc điểm quan trọng nhất

### first() cancel upstream NGAY KHI tìm thấy

```swift
let subject = PassthroughSubject<Int, Never>()

subject
    .handleEvents(
        receiveCancel: { print("⚠️ Upstream bị cancel!") }
    )
    .first()
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
    .store(in: &cancellables)

subject.send(1)     // Value: 1
                     // ⚠️ Upstream bị cancel!
                     // Completion: finished
subject.send(2)     // ← Không có hiệu lực — upstream đã bị cancel
subject.send(3)     // ← Không có hiệu lực
```

### Tiết kiệm resource với publisher tốn kém

```swift
// Publisher phát vô hạn — first() dừng sớm
Timer.publish(every: 0.1, on: .main, in: .common)
    .autoconnect()
    .first()
    .sink(
        receiveCompletion: { _ in print("Timer stopped") },
        receiveValue: { print("First tick: \($0)") }
    )
    .store(in: &cancellables)
// Chỉ nhận 1 tick, timer bị cancel ngay → không tốn resource
```

```swift
// Network: chỉ cần response đầu tiên từ nhiều source
let source1 = api.fetchFromCDN()       // có thể nhanh
let source2 = api.fetchFromOrigin()    // có thể chậm

source1.merge(with: source2)
    .first()
    // ← Response nào về trước → lấy, cancel cả hai
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { data in use(data) }
    )
    .store(in: &cancellables)
```

```
source1 (CDN):    ──────────data1──
source2 (Origin): ──data2──────────
merge:            ──data2──data1───
first():          ──data2──|
                           ↑ lấy data2 (về trước), cancel cả hai source
                             source1 không cần hoàn thành
```

---

## 6. Ứng dụng thực tế

### 6.1 Đợi điều kiện thoả mãn 1 lần

```swift
// Đợi user online rồi thực hiện action (chỉ 1 lần)
class SyncManager {
    private var cancellables = Set<AnyCancellable>()
    
    func syncWhenOnline() {
        networkMonitor.$isConnected
            .first(where: { $0 == true })
            // ↑ Đợi cho đến khi isConnected = true LẦN ĐẦU
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    self?.performSync()
                }
            )
            .store(in: &cancellables)
    }
}
```

```
$isConnected: ──false──false──true──false──true──
first(true):  ──────────────true──|
                                  ↑ chỉ trigger sync 1 lần
                                    cancel subscription
                                    false/true sau đó → bỏ qua
```

### 6.2 Lấy giá trị khởi tạo từ stream

```swift
// Lấy config ban đầu từ remote, chỉ cần 1 lần
configService.remoteConfigStream()     // publisher vô hạn
    .first()
    // ↑ Lấy config đầu tiên, cancel stream
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { [weak self] config in
            self?.applyConfig(config)
        }
    )
    .store(in: &cancellables)
```

### 6.3 Timeout pattern — Lấy response đầu tiên hoặc timeout

```swift
api.fetchData()
    .first()                    // chỉ cần response đầu tiên
    .timeout(.seconds(10), scheduler: RunLoop.main, customError: { .timedOut })
    .sink(
        receiveCompletion: { completion in
            if case .failure(.timedOut) = completion {
                print("Request timed out")
            }
        },
        receiveValue: { data in
            process(data)
        }
    )
    .store(in: &cancellables)
```

### 6.4 Tìm item đầu tiên thoả điều kiện trong stream

```swift
// Notification stream — tìm notification quan trọng đầu tiên
notificationService.notificationStream
    .first(where: { $0.priority == .critical })
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { notification in
            showCriticalAlert(notification)
        }
    )
    .store(in: &cancellables)
```

### 6.5 Form: submit khi validation pass lần đầu

```swift
// Đợi form valid lần đầu → auto-enable submit animation
Publishers.CombineLatest3($email, $password, $confirm)
    .map { email, pass, confirm in
        email.contains("@") && pass.count >= 8 && pass == confirm
    }
    .first(where: { $0 == true })
    // ↑ Lần đầu tiên form valid
    .sink(receiveValue: { _ in
        withAnimation(.spring) {
            showSubmitButton = true
            // Chỉ animate 1 lần khi form valid lần đầu
        }
    })
    .store(in: &cancellables)
```

### 6.6 Race condition — Publisher nào xong trước thắng

```swift
func fetchWithFallback() -> AnyPublisher<Data, Error> {
    let primary = api.fetchFromPrimary()
        .map { ($0, "primary") }
    
    let fallback = api.fetchFromFallback()
        .delay(for: .seconds(2), scheduler: RunLoop.main)
        // ↑ Cho primary 2 giây head start
        .map { ($0, "fallback") }
    
    return primary.merge(with: fallback)
        .first()
        // ↑ Ai trả về trước → lấy, cancel cái còn lại
        .map(\.0)    // bỏ label, giữ data
        .eraseToAnyPublisher()
}
```

---

## 7. first() vs last() — Hai đầu pipeline

```
                    first()                     last()
                    ───────                     ──────
Lấy value nào?     ĐẦU TIÊN                    CUỐI CÙNG
Cancel upstream?    ✅ NGAY khi tìm thấy        ❌ Đợi upstream complete
Cần upstream        ❌ Không                     ✅ Phải complete
complete?
Latency             Thấp (emit sớm)             Cao (đợi complete)
Publisher vô hạn?   ✅ Hoạt động (cancel sớm)   ❌ Không bao giờ emit
```

```swift
[1, 2, 3, 4, 5].publisher
    .first()
    .sink { print($0) }
// 1 (ngay lập tức, cancel upstream)

[1, 2, 3, 4, 5].publisher
    .last()
    .sink { print($0) }
// 5 (đợi upstream complete mới emit)
```

```
Input:  ──1──2──3──4──5──|

first():──1──|                    (emit ngay, cancel)
last():  ────────────────5──|     (đợi | rồi mới emit 5)
```

### Publisher vô hạn

```swift
// first() — hoạt động tốt
Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .first()       // ✅ Lấy tick đầu, cancel timer

// last() — KHÔNG BAO GIỜ emit
Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .last()        // ❌ Timer không bao giờ complete → last chờ mãi
```

---

## 8. first() vs prefix(1) — Sự khác biệt tinh tế

```swift
[1, 2, 3].publisher.first()
// Output: 1, finished

[1, 2, 3].publisher.prefix(1)
// Output: 1, finished
```

Kết quả **giống nhau** trong hầu hết trường hợp. Khác biệt ở **demand behavior** bên trong:

```
first():
  - Request .unlimited từ upstream
  - Nhận value đầu tiên → emit → cancel
  - Upstream có thể đã emit nhiều value trước khi cancel kịp

prefix(1):
  - Request .max(1) từ upstream
  - Upstream chỉ gửi đúng 1 value (back-pressure)
  - Chính xác hơn về demand
```

**Trong thực tế:** kết quả giống nhau. `first()` đọc rõ ý đồ hơn ("lấy cái đầu tiên"), `prefix(1)` rõ ý đồ "giới hạn 1" hơn.

### first(where:) vs prefix(while:) — KHÁC nhau hoàn toàn

```swift
[1, 2, 5, 3, 6].publisher
    .first(where: { $0 > 4 })
    .sink { print($0) }
// 5 (value ĐẦU TIÊN > 4, rồi dừng)

[1, 2, 5, 3, 6].publisher
    .prefix(while: { $0 < 4 })
    .sink { print($0) }
// 1, 2 (lấy TẤT CẢ values cho đến khi điều kiện false)
```

```
Input:           ──1──2──5──3──6──|

first(where: >4):─────────5──|        (TÌM 1 value match, dừng)

prefix(while: <4):──1──2──|           (LẤY TẤT CẢ while true, dừng khi false)
                           ↑ 5 < 4 = false → complete
```

---

## 9. first() vs output(at: 0) — Giống nhau

```swift
[10, 20, 30].publisher.first()
// 10

[10, 20, 30].publisher.output(at: 0)
// 10

// Kết quả giống nhau. first() đọc tự nhiên hơn.
// output(at: N) linh hoạt hơn: output(at: 2) → phần tử thứ 3
```

---

## 10. Kết hợp first() với operators khác

### + `filter` trước first — Lọc rồi lấy đầu tiên

```swift
// Tương đương first(where:) nhưng tách rõ logic
[1, 2, 3, 4, 5].publisher
    .filter { $0.isMultiple(of: 2) }    // 2, 4
    .first()                             // 2
    .sink { print($0) }
// 2
```

### + `map` trước first — Transform rồi lấy đầu tiên

```swift
usersPublisher
    .compactMap { $0.premiumExpiry }     // chỉ user có premium
    .first()                              // user premium đầu tiên
    .sink { expiryDate in
        showRenewalReminder(expiry: expiryDate)
    }
```

### + `timeout` — Giới hạn thời gian tìm

```swift
sensorDataStream
    .first(where: { $0.temperature > 100 })
    .timeout(.seconds(30), scheduler: RunLoop.main, customError: { .timedOut })
    .sink(
        receiveCompletion: { completion in
            if case .failure = completion {
                print("No high temp reading in 30 seconds")
            }
        },
        receiveValue: { reading in
            triggerAlarm(reading)
        }
    )
```

### + `combineLatest` + `first` — Đợi combo điều kiện

```swift
// Đợi cho đến khi CẢ user online VÀ có pending data
$isOnline.combineLatest($hasPendingData)
    .first(where: { isOnline, hasPending in
        isOnline && hasPending
    })
    .sink(receiveValue: { _, _ in
        startSync()
    })
    .store(in: &cancellables)
```

```
$isOnline:      ──false──true──true──false──true──
$hasPending:    ──true───true──false─true───true──
combineLatest:  ──(f,t)──(t,t)──(t,f)──(f,t)──(t,t)──
first(&&):      ──────── (t,t)──|
                                ↑ cả hai true lần đầu → trigger sync, dừng
```

### + `delay` + `first` — Đợi một khoảng rồi lấy giá trị

```swift
// Đợi scroll ổn định 0.5 giây rồi lấy vị trí
$scrollOffset
    .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
    .first()
    // ↑ Sau khi scroll dừng 0.5 giây → lấy offset → xong
    .sink { offset in
        saveScrollPosition(offset)
    }
    .store(in: &cancellables)
```

---

## 11. Sai lầm thường gặp

### ❌ Dùng first() trên publisher đã complete rỗng

```swift
Empty<Int, Never>()
    .first()
    .sink(
        receiveCompletion: { print($0) },      // finished
        receiveValue: { print($0) }             // KHÔNG gọi
    )
// Chỉ nhận finished — không có value
// Nếu logic phụ thuộc vào receiveValue → bug im lặng
```

### ❌ Nhầm first(where:) với filter + collect

```swift
// first(where:) → CHỈ 1 value đầu tiên match
[1, 2, 3, 4, 5, 6].publisher
    .first(where: { $0 > 3 })
    .sink { print($0) }
// 4 (CHỈ 4, không phải [4, 5, 6])

// filter → TẤT CẢ values match
[1, 2, 3, 4, 5, 6].publisher
    .filter { $0 > 3 }
    .sink { print($0) }
// 4, 5, 6
```

### ❌ first() trên publisher vô hạn không bao giờ emit

```swift
// PassthroughSubject — chưa send gì
let subject = PassthroughSubject<Int, Never>()

subject
    .first(where: { $0 > 100 })
    .sink(
        receiveCompletion: { _ in print("Done") },
        receiveValue: { print($0) }
    )
    .store(in: &cancellables)

// Nếu không bao giờ send value > 100 → subscription treo mãi
// Giải pháp: thêm .timeout()
```

---

## 12. Tóm tắt

| Operator | Lấy gì | Cancel upstream? | Cần complete? |
|---|---|---|---|
| `first()` | Value đầu tiên | ✅ Ngay | ❌ |
| `first(where:)` | Value đầu tiên thoả điều kiện | ✅ Khi match | Chỉ nếu không match |
| `tryFirst(where:)` | Như trên, closure có thể throw | ✅ Khi match/throw | Chỉ nếu không match |
| `last()` | Value cuối cùng | ❌ | ✅ Bắt buộc |
| `last(where:)` | Value cuối thoả điều kiện | ❌ | ✅ Bắt buộc |

| Khía cạnh | Chi tiết |
|---|---|
| **Bản chất** | Lấy 1 value (đầu tiên / đầu tiên match) → complete → cancel upstream |
| **Dùng khi** | Chỉ cần 1 kết quả: đợi điều kiện, lấy config đầu, race response, one-shot trigger |
| **Cancel sớm** | Tiết kiệm resource — dừng network, timer, sensor ngay khi có kết quả |
| **Không match** | `first(where:)` trên upstream complete mà không match → chỉ forward `.finished`, không emit value |
| **vs prefix(1)** | Kết quả giống, `first()` rõ ý đồ hơn |
| **vs filter** | `first(where:)` → 1 value rồi dừng. `filter` → tất cả value match |

----

`first()` và `first(where:)` lấy value đầu tiên (thoả điều kiện) rồi **ngay lập tức complete và cancel upstream**, Huy. Ba điểm cốt lõi:

**Cancel upstream là đặc điểm quan trọng nhất.** Khi tìm thấy value, `first()` gửi `.finished` VÀ cancel subscription với upstream. Publisher tốn kém (Timer, network, sensor) bị dừng ngay → tiết kiệm resource. Đây là lý do `first()` hoạt động tốt với publisher **vô hạn** (Timer, NotificationCenter), trong khi `last()` thì không (vì phải đợi upstream complete mà publisher vô hạn không bao giờ complete).

**`first()` vs `first(where:)`:** `first()` lấy value đầu tiên vô điều kiện. `first(where:)` kiểm tra từng value — skip nếu điều kiện false, lấy ngay khi điều kiện true. Nếu upstream complete mà không value nào match → chỉ forward `.finished`, **không emit value** → nếu logic phụ thuộc vào receiveValue thì sẽ là bug im lặng.

**Ứng dụng phổ biến nhất:** đợi điều kiện thoả mãn 1 lần (`$isConnected.first(where: { $0 == true })`), race condition giữa nhiều source (merge rồi `first()` — ai về trước thắng), lấy config khởi tạo từ stream, one-shot trigger. Thường kết hợp với `.timeout()` để tránh subscription treo mãi nếu không bao giờ match.
