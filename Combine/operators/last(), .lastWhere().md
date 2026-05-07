# Combine: `.last()` & `.last(where:)` — Giải thích chi tiết

## 1. Bản chất — Lấy value CUỐI CÙNG, phải ĐỢI upstream complete

`last()` và `last(where:)` là filtering operators ngược lại với `first()` — chúng lấy value **cuối cùng** (thoả điều kiện). Điểm khác biệt sống còn: chúng **bắt buộc đợi upstream complete** trước khi emit, vì không thể biết value nào là "cuối" cho đến khi upstream gửi `.finished`.

```
first():
Input:  ──1──2──3──4──5──|
Output: ──1──|                   ← emit NGAY, cancel upstream

last():
Input:  ──1──2──3──4──5──|
Output: ─────────────────5──|    ← ĐỢI upstream finished, rồi emit 5
```

Hình dung: `first()` là **bắt con cá đầu tiên rồi về**. `last()` là **đợi tất cả cá bơi qua, nhớ con cuối cùng, rồi mới về**.

---

## 2. `.last()` — Value cuối cùng, không điều kiện

### Cú pháp

```swift
publisher.last()
// Đợi upstream complete → emit value cuối cùng → complete
```

### Ví dụ cơ bản

```swift
[10, 20, 30, 40, 50].publisher
    .last()
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Value: 50
// Completion: finished
```

### Timeline chi tiết

```
Upstream: ──10──20──30──40──50──|
last():   ──────────────────────50──|
                                ↑
          Đợi upstream finished
          Nhớ value cuối cùng = 50
          Emit 50 → finished
```

**Bên trong `last()` đang làm gì trong lúc đợi:**

```
receive 10 → ghi nhớ: lastValue = 10
receive 20 → ghi nhớ: lastValue = 20  (ghi đè 10)
receive 30 → ghi nhớ: lastValue = 30  (ghi đè 20)
receive 40 → ghi nhớ: lastValue = 40  (ghi đè 30)
receive 50 → ghi nhớ: lastValue = 50  (ghi đè 40)
receive .finished → emit lastValue (50) → forward .finished
```

---

## 3. `.last(where:)` — Value cuối cùng thoả điều kiện

### Cú pháp

```swift
publisher.last(where: { value -> Bool in
    // return true  → GHI NHỚ value này (có thể bị ghi đè bởi match sau)
    // return false → BỎ QUA
})
// Sau khi upstream complete → emit value match CUỐI CÙNG
```

### Ví dụ cơ bản

```swift
[1, 2, 3, 4, 5, 6, 7, 8].publisher
    .last(where: { $0.isMultiple(of: 3) })
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Value: 6
// Completion: finished
```

### Timeline chi tiết

```
Upstream:          ──1──2──3──4──5──6──7──8──|
last(where: %3):   ──────────────────────────6──|

Bên trong:
receive 1 → 1 % 3 ≠ 0 → skip
receive 2 → 2 % 3 ≠ 0 → skip
receive 3 → 3 % 3 == 0 → lastMatch = 3 ✅
receive 4 → skip
receive 5 → skip
receive 6 → 6 % 3 == 0 → lastMatch = 6 ✅ (ghi đè 3)
receive 7 → skip
receive 8 → skip
receive .finished → emit lastMatch (6) → forward .finished
```

### Không tìm thấy match

```swift
[1, 2, 4, 5].publisher
    .last(where: { $0.isMultiple(of: 3) })
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
// Output:
// Completion: finished
// ← KHÔNG có value — không match nào → chỉ forward .finished
```

---

## 4. `.tryLast(where:)` — Closure có thể throw

```swift
publisher.tryLast(where: { value -> Bool in
    // Có thể throw → pipeline fail ngay lập tức
})
// Failure nới thành Error (giống mọi try* operator)
```

```swift
["10", "abc", "30", "40"].publisher
    .tryLast(where: { str in
        guard let num = Int(str) else {
            throw ParseError.invalidNumber(str)
        }
        return num > 20
    })
    .sink(
        receiveCompletion: { print($0) },
        receiveValue: { print($0) }
    )
// receive "10" → Int("10") = 10, 10 > 20 = false → skip
// receive "abc" → Int("abc") = nil → THROW → pipeline FAIL
// "30", "40" không bao giờ được kiểm tra

// Output:
// failure(ParseError.invalidNumber("abc"))
```

---

## 5. Đặc điểm cốt lõi — BẮT BUỘC đợi upstream complete

### Quy tắc

```
last() / last(where:) CHỈ emit khi upstream gửi .finished
  → Upstream complete          → emit value cuối (nếu có) + finished
  → Upstream fail (.failure)   → forward error, KHÔNG emit value
  → Upstream KHÔNG BAO GIỜ complete → KHÔNG BAO GIỜ emit
```

### ⚠️ Publisher vô hạn → last() TREO mãi mãi

```swift
// ❌ Timer KHÔNG BAO GIỜ complete → last() KHÔNG BAO GIỜ emit
Timer.publish(every: 1, on: .main, in: .common)
    .autoconnect()
    .last()
    .sink(
        receiveCompletion: { _ in print("Done") },    // KHÔNG BAO GIỜ gọi
        receiveValue: { _ in print("Value") }          // KHÔNG BAO GIỜ gọi
    )
    .store(in: &cancellables)
// ← Subscription sống mãi, last() buffer mãi, không emit gì

// ❌ @Published KHÔNG BAO GIỜ complete
$searchQuery
    .last()       // TREO mãi mãi
    .sink { ... } // KHÔNG BAO GIỜ gọi
```

### Publishers an toàn cho last()

```swift
// ✅ Sequence — complete sau phần tử cuối
[1, 2, 3].publisher.last()                    // → 3

// ✅ Just — complete sau 1 value
Just(42).last()                                // → 42

// ✅ URLSession — complete sau response
URLSession.shared.dataTaskPublisher(for: url)
    .last()                                    // → (Data, URLResponse)

// ✅ Future — complete sau 1 value
Future<Int, Never> { $0(.success(42)) }
    .last()                                    // → 42

// ✅ Subject — nếu gọi send(completion:)
let subject = PassthroughSubject<Int, Never>()
subject.last().sink { print($0) }.store(in: &cancellables)
subject.send(1)
subject.send(2)
subject.send(3)
subject.send(completion: .finished)            // → 3
```

---

## 6. Không cancel upstream — Khác first()

### first() vs last() — Behavior ngược nhau hoàn toàn

```swift
let subject = PassthroughSubject<Int, Never>()

// first(): cancel upstream NGAY
subject
    .handleEvents(receiveCancel: { print("first: 🛑 Cancelled") })
    .first()
    .sink(receiveValue: { print("first: \($0)") })
    .store(in: &cancellables)

subject.send(1)    // "first: 1" + "first: 🛑 Cancelled"
subject.send(2)    // không hiệu lực — đã cancel

// last(): KHÔNG cancel, đợi complete
subject
    .handleEvents(receiveCancel: { print("last: 🛑 Cancelled") })
    .last()
    .sink(receiveValue: { print("last: \($0)") })
    .store(in: &cancellables)

subject.send(1)    // im lặng — last() đang buffer
subject.send(2)    // im lặng — last() ghi đè: lastValue = 2
subject.send(3)    // im lặng — last() ghi đè: lastValue = 3
subject.send(completion: .finished)    // "last: 3"
```

### Bảng so sánh

```
                      first()                  last()
                      ───────                  ──────
Emit khi?             Nhận value đầu tiên      Upstream complete
Cancel upstream?      ✅ NGAY khi emit          ❌ KHÔNG — đợi complete
Publisher vô hạn?     ✅ Hoạt động              ❌ TREO mãi mãi
Latency               Thấp (sớm)               Cao (đợi complete)
Buffer                Không                    1 value (ghi đè liên tục)
```

---

## 7. Ứng dụng thực tế

### 7.1 Lấy kết quả cuối cùng của batch processing

```swift
// Upload nhiều ảnh — chỉ cần biết response cuối cùng
imageURLs.publisher
    .flatMap(maxPublishers: .max(3)) { url in
        api.uploadImage(url: url)
    }
    .last()
    // ↑ Đợi TẤT CẢ upload xong → lấy response cuối
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished: print("All uploads complete")
            case .failure(let error): print("Upload failed: \(error)")
            }
        },
        receiveValue: { lastResponse in
            print("Last upload response: \(lastResponse)")
        }
    )
    .store(in: &cancellables)
```

### 7.2 Lấy giá trị cuối cùng từ animation/transition

```swift
// Slider value — lấy giá trị cuối khi user thả tay
// (Kết hợp với subject có complete)
sliderValues.publisher     // sequence của values khi drag
    .last()
    .sink { finalValue in
        applyFilter(intensity: finalValue)
        // Chỉ apply filter 1 lần với giá trị cuối
    }
    .store(in: &cancellables)
```

### 7.3 Tìm record cuối cùng thoả điều kiện trong dataset

```swift
// Tìm transaction cuối cùng trong tháng > $1000
transactions.publisher
    .last(where: { transaction in
        transaction.amount > 1000 &&
        Calendar.current.isDate(transaction.date, equalTo: Date(), toGranularity: .month)
    })
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { transaction in
            highlightTransaction(transaction)
        }
    )
    .store(in: &cancellables)
```

### 7.4 Lấy error cuối cùng từ validation pipeline

```swift
struct ValidationResult {
    let field: String
    let isValid: Bool
    let message: String?
}

// Validate tất cả fields — lấy validation error CUỐI CÙNG
formFields.publisher
    .map { field in validate(field) }
    .last(where: { !$0.isValid })
    // ↑ Lấy field INVALID cuối cùng (để scroll tới / focus)
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { lastError in
            scrollToField(lastError.field)
            showError(lastError.message ?? "Invalid")
        }
    )
    .store(in: &cancellables)
```

### 7.5 Reduce alternative — Lấy accumulated value cuối cùng

```swift
// scan emit mỗi bước, last() chỉ lấy kết quả cuối
[10, 20, 30, 40].publisher
    .scan(0, +)                // 10, 30, 60, 100
    .last()                    // 100
    .sink { print("Total: \($0)") }
// Total: 100

// Tương đương .reduce(0, +) nhưng qua 2 bước
// .reduce() gọn hơn cho trường hợp này
```

### 7.6 Đợi tất cả tasks complete rồi lấy summary

```swift
func runMigrationSteps() -> AnyPublisher<MigrationSummary, Error> {
    migrationSteps.publisher
        .flatMap(maxPublishers: .max(1)) { step in
            // Chạy tuần tự từng step
            step.execute()
                .map { result in
                    MigrationSummary(
                        completedSteps: result.completedCount,
                        totalSteps: migrationSteps.count,
                        lastStep: step.name
                    )
                }
        }
        .last()
        // ↑ Đợi TẤT CẢ steps xong → lấy summary cuối cùng
        // Summary cuối chứa completedSteps = totalSteps
        .eraseToAnyPublisher()
}
```

---

## 8. Error Behavior

### Upstream fail → forward error, KHÔNG emit value

```swift
let subject = PassthroughSubject<Int, MyError>()

subject
    .last()
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
    .store(in: &cancellables)

subject.send(1)      // buffer: lastValue = 1
subject.send(2)      // buffer: lastValue = 2
subject.send(completion: .failure(.networkError))

// Output:
// Completion: failure(MyError.networkError)
// ← Value 2 KHÔNG được emit — error có priority cao hơn
```

```
subject: ──1──2──✗(error)
last():  ──────────✗(error)
                   ↑ forward error, KHÔNG emit buffered value (2)
```

### Kết hợp catch để recovery

```swift
api.fetchAllPages()
    .last()
    .catch { error -> Just<Page> in
        print("Error: \(error), using cached last page")
        return Just(Page.cached)
    }
    .sink(receiveValue: { lastPage in
        display(lastPage)
    })
    .store(in: &cancellables)
```

---

## 9. last() vs các operators khác

### last() vs reduce()

```swift
// last() — lấy value cuối
[1, 2, 3, 4, 5].publisher.last()
// → 5

// reduce() — tính toán qua tất cả values, emit 1 kết quả cuối
[1, 2, 3, 4, 5].publisher.reduce(0, +)
// → 15

// Cả hai đều: đợi complete → emit 1 value → finished
// Khác nhau: last() giữ nguyên value, reduce() transform/accumulate
```

### last() vs output(at:)

```swift
// last() — value cuối, không cần biết trước số lượng
[10, 20, 30].publisher.last()       // 30

// output(at:) — value tại index cụ thể, cần biết index
[10, 20, 30].publisher.output(at: 2)   // 30

// last() linh hoạt hơn khi không biết trước collection size
```

### last(where:) vs filter + last

```swift
// Tương đương logic:
[1, 2, 3, 4, 5, 6].publisher
    .last(where: { $0.isMultiple(of: 2) })
// → 6

[1, 2, 3, 4, 5, 6].publisher
    .filter { $0.isMultiple(of: 2) }
    .last()
// → 6

// Kết quả giống nhau. last(where:) gọn hơn 1 bước.
// filter + last hiển thị rõ pipeline hơn khi logic phức tạp.
```

### last() vs collect() + map(\.last)

```swift
// last() — hiệu quả: chỉ buffer 1 value
[1, 2, 3, 4, 5].publisher.last()
// Memory: O(1) — ghi đè liên tục

// collect() + map — tốn memory: buffer TẤT CẢ values
[1, 2, 3, 4, 5].publisher
    .collect()
    .compactMap(\.last)
// Memory: O(N) — giữ toàn bộ array

// → last() tốt hơn cho bài toán "lấy cuối cùng"
```

---

## 10. Kết hợp với operators khác

### + `prefix` trước last — Giới hạn rồi lấy cuối

```swift
// Lấy value cuối cùng trong 5 value đầu tiên
[10, 20, 30, 40, 50, 60, 70].publisher
    .prefix(5)           // 10, 20, 30, 40, 50 → complete
    .last()              // 50
    .sink { print($0) }
// 50
```

### + `filter` trước last — Lọc rồi lấy cuối

```swift
[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].publisher
    .filter { $0.isMultiple(of: 3) }    // 3, 6, 9
    .last()                              // 9
    .sink { print($0) }
// 9
```

### + `map` trước last — Transform rồi lấy cuối

```swift
users.publisher
    .map(\.lastLoginDate)
    .last()
    .sink { lastLogin in
        print("Most recent login from last user: \(lastLogin)")
    }
```

### + `timeout` — Giới hạn thời gian đợi complete

```swift
// Đợi upstream complete tối đa 10 giây
longRunningPublisher
    .timeout(.seconds(10), scheduler: RunLoop.main, customError: { .timedOut })
    .last()
    .sink(
        receiveCompletion: { completion in
            if case .failure(.timedOut) = completion {
                print("Waited too long for completion")
            }
        },
        receiveValue: { lastValue in
            process(lastValue)
        }
    )
    .store(in: &cancellables)
```

### + `removeDuplicates` trước last(where:) — Loại trùng trước khi tìm

```swift
sensorReadings.publisher
    .removeDuplicates()
    .last(where: { $0.value > criticalThreshold })
    .sink { reading in
        logCriticalReading(reading)
    }
```

---

## 11. Sai lầm thường gặp

### ❌ Dùng last() trên publisher vô hạn

```swift
// ❌ TREO mãi mãi
$searchQuery.last().sink { ... }              // @Published không complete
Timer.publish(...).autoconnect().last()        // Timer không complete
NotificationCenter.default.publisher(for: ...).last()  // không complete

// ✅ Thêm prefix hoặc timeout để giới hạn
$searchQuery
    .prefix(untilOutputFrom: cancelTrigger)    // complete khi cancel trigger
    .last()
    .sink { ... }
```

### ❌ Mong đợi last() emit trước khi upstream complete

```swift
let subject = PassthroughSubject<Int, Never>()

subject.last()
    .sink { print("Last: \($0)") }
    .store(in: &cancellables)

subject.send(1)    // im lặng
subject.send(2)    // im lặng
subject.send(3)    // im lặng
// ← "Last: 3" CHƯA xuất hiện! Phải gọi:
subject.send(completion: .finished)
// ← BÂY GIỜ mới: "Last: 3"
```

### ❌ Nhầm last(where:) chỉ kiểm tra phần tử cuối

```swift
// last(where:) kiểm tra TẤT CẢ phần tử, GHI NHỚ match cuối
[1, 4, 2, 5, 3].publisher
    .last(where: { $0 > 3 })
    .sink { print($0) }
// → 5 (KHÔNG phải 3 — 3 không match; 5 là match CUỐI CÙNG)

// Nếu muốn kiểm tra CHỈ phần tử cuối:
[1, 4, 2, 5, 3].publisher
    .last()                          // 3
    .filter { $0 > 3 }              // 3 > 3 = false → không emit
    .sink { print($0) }
// Không output (3 không > 3)
```

### ❌ Quên handle trường hợp upstream rỗng

```swift
// Publisher rỗng → last() chỉ forward .finished, không emit value
[Int]().publisher
    .last()
    .sink(
        receiveCompletion: { print("Done: \($0)") },   // "Done: finished"
        receiveValue: { print("Value: \($0)") }         // KHÔNG gọi
    )
// Nếu logic phụ thuộc receiveValue → bug im lặng

// ✅ Handle trong receiveCompletion hoặc dùng replaceEmpty
[Int]().publisher
    .last()
    .replaceEmpty(with: 0)      // không có value → dùng default 0
    .sink(receiveValue: { print("Value: \($0)") })
// Value: 0
```

---

## 12. Tóm tắt tất cả biến thể last

| Operator | Điều kiện | Throw? | Failure output |
|---|---|---|---|
| `last()` | Không | ❌ | Giữ nguyên |
| `last(where:)` | `(Value) -> Bool` | ❌ | Giữ nguyên |
| `tryLast(where:)` | `(Value) throws -> Bool` | ✅ | Nới thành `Error` |

| Khía cạnh | Chi tiết |
|---|---|
| **Bản chất** | Lấy value cuối cùng (thoả điều kiện) → phải ĐỢI upstream complete |
| **Bắt buộc** | Upstream phải gửi `.finished` → nếu không → TREO mãi mãi |
| **Cancel upstream?** | ❌ KHÔNG — đợi đến khi complete |
| **Publisher vô hạn** | ❌ Không dùng được (Timer, @Published, NotificationCenter) |
| **Buffer** | O(1) — chỉ ghi nhớ 1 value (ghi đè liên tục) |
| **Upstream fail** | Forward error, KHÔNG emit buffered value |
| **Không match** | Chỉ forward `.finished`, không emit value |
| **vs first()** | first: emit sớm + cancel. last: đợi complete + không cancel |
| **Dùng khi** | Kết quả cuối của batch, summary sau processing, value cuối trong finite stream |

----

`last()` và `last(where:)` là "bản ngược" của `first()` — lấy value cuối cùng thay vì đầu tiên, Huy. Nhưng behavior khác nhau hoàn toàn ở một điểm:

**BẮT BUỘC đợi upstream complete.** Đây là đặc điểm sống còn. `first()` emit ngay khi nhận value đầu → cancel upstream. `last()` **không thể biết value nào là cuối** cho đến khi upstream gửi `.finished` → phải đợi. Bên trong, nó chỉ buffer 1 value (O(1) memory), ghi đè liên tục mỗi khi nhận value mới, rồi emit khi upstream complete.

**Publisher vô hạn = TREO mãi mãi.** Timer, `@Published`, NotificationCenter không bao giờ complete → `last()` không bao giờ emit → subscription treo im lặng, không lỗi, không warning. Đây là sai lầm phổ biến nhất. Chỉ dùng `last()` với publisher **chắc chắn complete**: `[].publisher`, `Just`, `URLSession`, `Future`, hoặc Subject có gọi `send(completion: .finished)`.

**`last(where:)` kiểm tra TẤT CẢ value, ghi nhớ match cuối.** Không phải chỉ kiểm tra phần tử cuối cùng. `[1, 4, 2, 5, 3].last(where: { $0 > 3 })` → 5 (match cuối cùng), không phải 3 (phần tử cuối). Nó scan toàn bộ stream, ghi đè lastMatch mỗi khi gặp match mới, emit lastMatch khi upstream complete.

**Upstream fail → error forward, value KHÔNG emit.** Dù đã buffer value, khi nhận `.failure` thì forward error mà bỏ buffered value. Dùng `.catch` nếu cần recovery.
