# Combine: `.ignoreOutput()` — Giải thích chi tiết

## 1. Bản chất — Bỏ tất cả value, chỉ giữ completion

`ignoreOutput()` là operator **loại bỏ mọi value** mà upstream emit, chỉ để completion (`.finished` hoặc `.failure`) đi qua. Output type chuyển thành `Never`.

```swift
[1, 2, 3, 4, 5].publisher
    .ignoreOutput()
    .sink(
        receiveCompletion: { print($0) },    // finished ✅
        receiveValue: { print($0) }           // KHÔNG BAO GIỜ gọi
    )
// Output: finished
```

```
TRƯỚC ignoreOutput():
──1──2──3──4──5──|
  ↑  ↑  ↑  ↑  ↑  ↑
 val val val val val finished

SAU ignoreOutput():
─────────────────|
                  ↑
              finished (chỉ còn completion)
```

Hình dung: đường ống nước có **bộ lọc** chặn tất cả nước (value) nhưng vẫn cho tín hiệu "hết nước" (completion) hoặc "ống vỡ" (failure) đi qua.

---

## 2. Type Transformation

```swift
let publisher = [1, 2, 3].publisher
// Type: Publishers.Sequence<[Int], Never>
// Output = Int, Failure = Never

let ignored = publisher.ignoreOutput()
// Type: Publishers.IgnoreOutput<Publishers.Sequence<[Int], Never>>
// Output = Never  ← THAY ĐỔI
// Failure = Never  ← GIỮ NGUYÊN
```

**Output chuyển thành `Never`** — compiler đảm bảo `receiveValue` không bao giờ được gọi. Failure giữ nguyên — error vẫn đi qua bình thường.

```swift
// Với publisher có error
let networkPub = URLSession.shared.dataTaskPublisher(for: url)
// <(Data, URLResponse), URLError>

networkPub.ignoreOutput()
// <Never, URLError>
// Value bị bỏ, error vẫn giữ
```

---

## 3. Tại sao cần? — Chỉ quan tâm "xong chưa", không quan tâm "xong cái gì"

### Tình huống: Chỉ cần biết operation hoàn thành

```swift
// Upload file — không cần response body, chỉ cần biết thành công/thất bại
api.uploadFile(data: fileData)
    .ignoreOutput()
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("Upload thành công!")
            case .failure(let error):
                print("Upload thất bại: \(error)")
            }
        },
        receiveValue: { _ in }
        // ← receiveValue closure vẫn bắt buộc viết nhưng KHÔNG BAO GIỜ chạy
    )
```

### Tình huống: Side effect pipeline — chỉ cần trigger, không cần kết quả

```swift
// Ghi log, sync data, invalidate cache — không cần return value
cacheService.invalidateAll()
    .ignoreOutput()
    // "Tôi chỉ cần biết cache đã invalidate xong"
```

---

## 4. Ứng dụng thực tế

### 4.1 Đợi operation hoàn thành trước khi làm tiếp

```swift
class SyncViewModel: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var syncError: String?
    private var cancellables = Set<AnyCancellable>()
    
    func syncData() {
        isSyncing = true
        syncError = nil
        
        // Bước 1: Upload pending changes (không cần response body)
        api.uploadPendingChanges()
            .ignoreOutput()
            // ↑ Không quan tâm server trả gì, chỉ cần biết xong chưa
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isSyncing = false
                    switch completion {
                    case .finished:
                        print("Sync complete")
                    case .failure(let error):
                        self?.syncError = error.localizedDescription
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}
```

### 4.2 Chuyển publisher thành "completion signal" cho Zip/CombineLatest

```swift
// Đợi NHIỀU operations hoàn thành, không cần kết quả từng cái
let uploadDone = api.uploadPhotos(photos)
    .ignoreOutput()                                // <Never, Error>

let syncDone = api.syncContacts()
    .ignoreOutput()                                // <Never, Error>

let cacheDone = cacheService.warmUp()
    .ignoreOutput()                                // <Never, Error>

// ⚠️ Không dùng zip/combineLatest với Output = Never trực tiếp
// Dùng pattern khác: xem section 4.3
```

### 4.3 Pattern: `ignoreOutput` + `map` để tạo trigger signal

```swift
// ignoreOutput → Output = Never → khó dùng tiếp trong pipeline
// Giải pháp: map thành Void TRƯỚC ignoreOutput, hoặc dùng pattern khác

// Pattern 1: Dùng .map + .last thay vì ignoreOutput
api.uploadPhotos(photos)
    .map { _ in () }         // <Void, Error> — bỏ value cụ thể, giữ "event"
    .last()                   // Chỉ emit Void cuối cùng khi complete
    .sink(
        receiveCompletion: { ... },
        receiveValue: { _ in print("All photos uploaded") }
    )

// Pattern 2: handleEvents + ignoreOutput cho side effect chain
api.deleteAccount()
    .handleEvents(receiveCompletion: { completion in
        if case .finished = completion {
            LocalDatabase.clearAll()    // side effect khi xong
        }
    })
    .ignoreOutput()
    .sink(
        receiveCompletion: { completion in
            // Handle final result
        },
        receiveValue: { _ in }
    )
    .store(in: &cancellables)
```

### 4.4 Prefix + IgnoreOutput — Đợi điều kiện thoả mãn

```swift
// Đợi cho đến khi user online, không quan tâm giá trị cụ thể
networkMonitor.$isConnected
    .filter { $0 == true }           // chỉ giữ khi online
    .first()                          // lấy event đầu tiên
    .ignoreOutput()                   // không cần giá trị Bool
    .sink(
        receiveCompletion: { _ in
            print("User is now online — start syncing")
            self.startSync()
        },
        receiveValue: { _ in }
    )
    .store(in: &cancellables)
```

```
$isConnected: ──false──false──true──false──true──
filter(true): ──────────────true──────────
first():      ──────────────true──|
ignoreOutput():───────────────────|
                                   ↑ completion → trigger sync
```

### 4.5 Unit Test — Verify publisher completes

```swift
func testUploadCompletes() {
    let expectation = XCTestExpectation(description: "Upload completes")
    
    sut.upload(data: testData)
        .ignoreOutput()
        // Không quan tâm response, chỉ verify completion
        .sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    expectation.fulfill()    // ✅ test pass
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
    
    wait(for: [expectation], timeout: 5.0)
}
```

### 4.6 Chain operations tuần tự — operation A xong rồi mới B

```swift
func migrateDatabase() -> AnyPublisher<Void, Error> {
    // Step 1: Backup
    backupService.createBackup()
        .ignoreOutput()
        // Step 1 xong → trigger step 2
        .flatMap { _ -> AnyPublisher<Void, Error> in
            // ⚠️ flatMap trên Never không emit → dùng pattern khác
            // Xem section 5 cho cách đúng
        }
        .eraseToAnyPublisher()
}

// ✅ Pattern đúng cho sequential operations:
func migrateDatabase() -> AnyPublisher<Void, Error> {
    backupService.createBackup()
        .map { _ in () }        // Data → Void (giữ event, bỏ data)
        .last()                  // Chỉ Void cuối cùng
        .flatMap { _ in
            self.migrationService.runMigration()
                .map { _ in () }
                .last()
        }
        .flatMap { _ in
            self.cleanupService.removeOldData()
                .map { _ in () }
                .last()
        }
        .eraseToAnyPublisher()
}
```

---

## 5. Gotcha: `ignoreOutput()` + `flatMap` = Không bao giờ emit

Đây là **bẫy phổ biến nhất**:

```swift
// ❌ flatMap SAU ignoreOutput KHÔNG BAO GIỜ chạy
api.uploadData(data)
    .ignoreOutput()           // Output = Never
    .flatMap { _ in           // ← closure KHÔNG BAO GIỜ được gọi
        api.fetchUpdatedData() //   vì ignoreOutput không emit value
    }
    .sink(...)
// ← fetchUpdatedData() KHÔNG BAO GIỜ chạy!
```

**Lý do:** `ignoreOutput()` bỏ **tất cả value**. `flatMap` chỉ chạy khi nhận value. Không có value → flatMap không chạy → downstream im lặng.

```
uploadData:    ──data1──data2──|
ignoreOutput:  ────────────────|           ← chỉ completion, không value
flatMap:       (không bao giờ gọi closure) ← không có value để trigger
sink:          ────────────────|           ← chỉ nhận completion, không value
```

### Giải pháp

```swift
// Giải pháp 1: map → last thay vì ignoreOutput
api.uploadData(data)
    .map { _ in () }          // Data → Void (giữ event)
    .last()                    // 1 Void khi complete
    .flatMap { _ in
        api.fetchUpdatedData() // ✅ chạy sau upload xong
    }
    .sink(...)

// Giải pháp 2: handleEvents cho side effect, không dùng ignoreOutput
api.uploadData(data)
    .last()                    // value cuối trước completion
    .flatMap { _ in
        api.fetchUpdatedData()
    }
    .sink(...)

// Giải pháp 3: Dùng append thay vì flatMap
api.uploadData(data)
    .ignoreOutput()
    .append(api.fetchUpdatedData())
    // ↑ append chờ upstream COMPLETE (không cần value)
    // rồi subscribe vào publisher tiếp theo
    .sink(...)
```

### `append` — Giải pháp tự nhiên nhất cho sequential operations

```swift
// append KHÔNG cần value từ upstream — chỉ cần completion
operationA()
    .ignoreOutput()                    // <Never, Error>
    .append(operationB())             // chờ A xong → chạy B
    .ignoreOutput()                    // bỏ value B
    .append(operationC())             // chờ B xong → chạy C
    .sink(
        receiveCompletion: { completion in
            // A → B → C đều xong (hoặc 1 trong 3 fail)
        },
        receiveValue: { finalValue in
            // value từ C (operation cuối)
        }
    )
```

```
operationA: ──v1──v2──|
ignoreOutput:─────────|
append(B):  ──────────v3──v4──|        ← B bắt đầu sau A xong
ignoreOutput:─────────────────|
append(C):  ──────────────────v5──|    ← C bắt đầu sau B xong
sink:       ──────────────────v5──|    ← nhận value từ C
```

---

## 6. ignoreOutput vs drop/filter — So sánh

```swift
// ignoreOutput: BỎ TẤT CẢ value, Output thành Never
publisher.ignoreOutput()
// Trước: <String, Error> → Sau: <Never, Error>

// filter { false }: BỎ TẤT CẢ value, Output GIỮ NGUYÊN type
publisher.filter { _ in false }
// Trước: <String, Error> → Sau: <String, Error>
// Không emit value nhưng type vẫn là String

// Khác biệt quan trọng:
publisher.ignoreOutput().map { $0 }       // ❌ $0 là Never — không dùng được
publisher.filter { _ in false }.map { $0 } // ✅ $0 là String — dùng được (dù không emit)
```

```
                    ignoreOutput()         filter { false }
                    ──────────────         ────────────────
Output type         Never                  Giữ nguyên
Value emit          0                      0
Completion          ✅ Forward             ✅ Forward
Error               ✅ Forward             ✅ Forward
Dùng sau đó         Hạn chế (Never)        Bình thường
Ý nghĩa             "Chỉ cần completion"   "Lọc hết, giữ type"
```

---

## 7. Kết hợp phổ biến

### + `sink(receiveCompletion:receiveValue:)`

```swift
// receiveValue bắt buộc viết nhưng không bao giờ gọi
publisher.ignoreOutput()
    .sink(
        receiveCompletion: { completion in ... },
        receiveValue: { _ in }     // ← dead code nhưng compiler yêu cầu
    )
```

### + `handleEvents` (trước ignoreOutput) — Log/debug values

```swift
api.uploadBatch(items)
    .handleEvents(receiveOutput: { response in
        print("Uploaded: \(response.id)")    // log từng response
    })
    .ignoreOutput()                           // rồi bỏ hết
    .sink(
        receiveCompletion: { print("Batch done: \($0)") },
        receiveValue: { _ in }
    )
```

### + `append` — Chain sequential operations

```swift
stepA().ignoreOutput()
    .append(stepB())
    .ignoreOutput()
    .append(stepC())
    .sink(...)
```

### + `setFailureType` — Khớp error type

```swift
Just("cached")                        // <String, Never>
    .ignoreOutput()                    // <Never, Never>
    .setFailureType(to: APIError.self) // <Never, APIError>
    .append(api.fetchFresh())          // <String, APIError>
    .sink(...)
```

### + `timeout` — Giới hạn thời gian chờ completion

```swift
longRunningOperation()
    .ignoreOutput()
    .timeout(.seconds(30), scheduler: RunLoop.main, customError: { .timedOut })
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished: print("Done in time")
            case .failure(.timedOut): print("Too slow!")
            case .failure(let other): print("Error: \(other)")
            }
        },
        receiveValue: { _ in }
    )
```

---

## 8. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Operator bỏ tất cả value, chỉ để completion đi qua |
| **Output sau** | `Never` — compiler đảm bảo receiveValue không bao giờ gọi |
| **Failure** | Giữ nguyên — error vẫn forward bình thường |
| **Dùng khi** | Chỉ cần biết "xong chưa / lỗi chưa", không cần data |
| **⚠️ Gotcha** | `ignoreOutput()` + `flatMap` = flatMap KHÔNG BAO GIỜ chạy |
| **Giải pháp chain** | Dùng `.append()` thay vì `.flatMap` sau `ignoreOutput` |
| **Alternative** | `.map { _ in () }.last()` — giữ 1 event trigger cuối |
| **Use cases** | Upload, sync, cache invalidation, đợi operation xong, unit test verify completion |

------

`ignoreOutput()` bỏ tất cả value, chỉ để completion đi qua — dùng khi chỉ cần biết **"xong chưa / lỗi chưa"** mà không cần data, Huy. Ba điểm cốt lõi:

**Output chuyển thành `Never`:** Compiler đảm bảo `receiveValue` không bao giờ được gọi. Failure giữ nguyên — error vẫn forward bình thường. Ứng dụng phổ biến: upload file (không cần response body), sync data, cache invalidation, delete operation.

**Bẫy lớn nhất: `ignoreOutput()` + `flatMap` = flatMap KHÔNG BAO GIỜ chạy.** Đây là sai lầm rất phổ biến. `flatMap` cần value để trigger closure, nhưng `ignoreOutput` đã bỏ hết value → flatMap im lặng mãi mãi. Giải pháp tốt nhất là dùng **`.append()`** thay vì `.flatMap` — `append` chờ upstream **complete** (không cần value) rồi subscribe publisher tiếp theo:

```swift
stepA().ignoreOutput()
    .append(stepB())    // B chạy sau A complete
    .ignoreOutput()
    .append(stepC())    // C chạy sau B complete
```

**Khi nào dùng `ignoreOutput()` vs `.map { _ in () }.last()`:** Nếu sau đó cần **chain tiếp với flatMap** → dùng `.map { _ in () }.last()` (giữ 1 Void event). Nếu chỉ cần **sink completion** hoặc **append operation tiếp theo** → dùng `ignoreOutput()` gọn hơn.
