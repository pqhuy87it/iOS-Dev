# Combine: `.tryFirst(where:)` — Giải thích chi tiết

## 1. Bản chất — `first(where:)` có khả năng throw

`tryFirst(where:)` tìm value **đầu tiên** thoả điều kiện trong closure — nhưng closure **có thể throw error**. Khi throw, pipeline **fail ngay lập tức** thay vì tiếp tục tìm.

```swift
publisher.tryFirst(where: { value -> Bool in
    // Có thể throw error ở đây
    // return true  → LẤY value này, complete
    // return false → BỎ QUA, kiểm tra value tiếp
    // throw error  → PIPELINE FAIL ngay
})
```

```
first(where:):     Closure trả Bool         → không bao giờ fail vì closure
tryFirst(where:):  Closure trả Bool hoặc THROW → có thể fail giữa chừng
```

---

## 2. So sánh 3 biến thể first

### `first()` — Không điều kiện

```swift
[1, 2, 3].publisher.first()
// → 1 (value đầu tiên, xong)
// Failure: giữ nguyên upstream
```

### `first(where:)` — Có điều kiện, không throw

```swift
[1, 2, 3].publisher.first(where: { $0 > 2 })
// → 3 (value đầu tiên > 2, xong)
// Failure: giữ nguyên upstream
```

### `tryFirst(where:)` — Có điều kiện, có thể throw

```swift
[1, 2, 3].publisher.tryFirst(where: { value in
    guard value != 2 else { throw MyError.invalid }
    return value > 2
})
// → 1: return false (skip)
// → 2: THROW MyError.invalid → pipeline FAIL
// → 3: không bao giờ được kiểm tra
// Failure: NỚI thành Error (dù upstream là Never)
```

---

## 3. Failure Type — Nới thành `Error`

Giống mọi `try*` operator trong Combine, `tryFirst(where:)` **nới Failure thành `Error`** (protocol gốc):

```swift
[1, 2, 3].publisher                    // <Int, Never>
    .tryFirst(where: { $0 > 2 })       // <Int, Error>
//                                        ↑ Never → Error

URLSession.shared.dataTaskPublisher(for: url)   // <(Data, Response), URLError>
    .tryFirst(where: { ... })                    // <(Data, Response), Error>
//                                                  ↑ URLError → Error
```

**Lý do:** Swift `throws` chỉ biết kiểu `Error` protocol, không biết concrete type → Combine buộc Failure = `Error`.

Nếu cần concrete error type ở downstream → dùng `mapError` sau:

```swift
publisher
    .tryFirst(where: { ... })                           // <T, Error>
    .mapError { $0 as? MyError ?? .unknown }            // <T, MyError>
```

---

## 4. Ba kịch bản kết quả

### Kịch bản 1: Tìm thấy value match → emit + complete

```swift
[10, 20, 30, 40].publisher
    .tryFirst(where: { value in
        let isValid = try validate(value)   // không throw
        return value > 25                    // true khi value = 30
    })
    .sink(
        receiveCompletion: { print($0) },   // finished
        receiveValue: { print($0) }          // 30
    )
```

```
Input:         ──10──20──30──40──|
tryFirst(>25): ──────────30──|
               skip  skip  MATCH → emit 30, finished, cancel upstream
```

### Kịch bản 2: Closure throw → fail ngay lập tức

```swift
[10, 20, 30, 40].publisher
    .tryFirst(where: { value in
        guard value != 20 else {
            throw ValidationError.blacklisted(value)    // THROW!
        }
        return value > 25
    })
    .sink(
        receiveCompletion: { print($0) },   // failure(ValidationError.blacklisted(20))
        receiveValue: { print($0) }          // KHÔNG gọi
    )
```

```
Input:         ──10──20──30──40──|
tryFirst:      ──────✗
               skip  THROW → pipeline fail, cancel upstream
                     30, 40 không bao giờ được kiểm tra
```

### Kịch bản 3: Không tìm thấy + không throw → chỉ complete

```swift
[10, 20, 30].publisher
    .tryFirst(where: { value in
        // Không throw, nhưng không value nào > 100
        return value > 100
    })
    .sink(
        receiveCompletion: { print($0) },   // finished
        receiveValue: { print($0) }          // KHÔNG gọi
    )
```

```
Input:          ──10──20──30──|
tryFirst(>100): ──────────────|
                skip skip skip upstream finished → forward finished
                               không value nào emit
```

---

## 5. Ứng dụng thực tế

### 5.1 Parse + tìm — Parse có thể fail

```swift
// Stream các JSON strings — tìm record đầu tiên có field "priority" = "high"
jsonStrings.publisher
    .tryFirst(where: { jsonString in
        // Parse có thể throw
        guard let data = jsonString.data(using: .utf8) else {
            throw ParseError.invalidEncoding
        }
        let record = try JSONDecoder().decode(Record.self, from: data)
        return record.priority == .high
    })
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Parse failed: \(error)")
            }
        },
        receiveValue: { jsonString in
            print("Found high priority record: \(jsonString)")
        }
    )
    .store(in: &cancellables)
```

```
Input:  ──"{low}"──"{bad json}"──"{high}"──
tryFirst:          ✗
         skip      THROW ParseError → fail
                   "{high}" không bao giờ được kiểm tra
```

### 5.2 Validate từng item cho đến khi tìm được item hợp lệ

```swift
enum ValidationError: Error {
    case expired, revoked, invalidFormat
}

// Tìm license hợp lệ đầu tiên trong danh sách
licenses.publisher
    .tryFirst(where: { license in
        // Validation có thể throw nếu format sai hoàn toàn
        guard license.format == .standard else {
            throw ValidationError.invalidFormat
        }
        // Không throw nhưng trả false nếu expired/revoked
        return !license.isExpired && !license.isRevoked
    })
    .mapError { $0 as? ValidationError ?? .invalidFormat }
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                switch error {
                case .invalidFormat: showFormatError()
                case .expired: showExpiredError()
                case .revoked: showRevokedError()
                }
            }
        },
        receiveValue: { license in
            activateLicense(license)
        }
    )
    .store(in: &cancellables)
```

**Logic:**
- Format sai → **throw** (dừng ngay, không kiểm tra tiếp — lỗi nghiêm trọng)
- Expired/revoked → **return false** (skip, tiếp tục tìm — lỗi nhẹ)
- Hợp lệ → **return true** (lấy, xong)

### 5.3 Tìm trong database với query có thể fail

```swift
// Tìm user đầu tiên thoả điều kiện phức tạp
userIDStream
    .tryFirst(where: { [weak self] userID in
        guard let self else { throw AppError.deallocated }
        
        // Database query có thể throw
        let user = try self.database.fetchUser(id: userID)
        
        // Business rule check
        return user.subscription == .premium && user.isActive
    })
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Database error: \(error)")
            }
        },
        receiveValue: { userID in
            navigateToUser(userID)
        }
    )
    .store(in: &cancellables)
```

### 5.4 File processing — Tìm file hợp lệ đầu tiên

```swift
filePaths.publisher
    .tryFirst(where: { path in
        // Đọc file có thể throw (permission, corrupt, missing)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let header = try FileHeader.parse(data)
        return header.version >= requiredVersion
    })
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("No compatible file found")
            case .failure(let error):
                print("File read error: \(error)")
            }
        },
        receiveValue: { path in
            print("Found compatible file: \(path)")
        }
    )
    .store(in: &cancellables)
```

### 5.5 Network — Tìm server available đầu tiên

```swift
serverURLs.publisher
    .tryFirst(where: { url in
        // Health check có thể throw (network error, timeout)
        let (_, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw ServerError.invalidResponse
        }
        return http.statusCode == 200
    })
    .sink(
        receiveCompletion: { completion in
            if case .failure = completion {
                print("All servers unreachable")
            }
        },
        receiveValue: { url in
            print("Using server: \(url)")
            connectToServer(url)
        }
    )
    .store(in: &cancellables)
```

---

## 6. `tryFirst(where:)` vs `first(where:)` — Khi nào dùng cái nào

```
Closure chỉ kiểm tra điều kiện thuần (so sánh, check property)?
  → first(where:) ✅
  
  [1, 2, 3].first(where: { $0 > 2 })
  users.first(where: { $0.isActive })

Closure có operation có thể fail (parse, decode, I/O, network)?
  → tryFirst(where:) ✅
  
  data.tryFirst(where: { try JSONDecoder().decode(T.self, from: $0).isValid })
  files.tryFirst(where: { try Data(contentsOf: $0).count > 0 })
```

### Quyết định: throw vs return false

```swift
// THROW khi: lỗi nghiêm trọng, pipeline nên DỪNG
// return false khi: item không match nhưng không phải lỗi, tiếp tục tìm

items.publisher
    .tryFirst(where: { item in
        // Lỗi nghiêm trọng → throw → dừng toàn bộ
        guard item.data != nil else {
            throw ItemError.corrupted(item.id)
        }
        
        // Không match → return false → tìm tiếp
        guard item.status == .active else {
            return false
        }
        
        // Match → return true → lấy item này
        return true
    })
```

```
item1: data=nil   → THROW .corrupted → DỪNG (lỗi nghiêm trọng)
item1: status=inactive → return false → TIẾP TỤC (chỉ skip)
item1: status=active   → return true  → LẤY (match)
```

---

## 7. Pattern: `tryFirst(where:)` + `mapError` + Exhaustive Switch

```swift
enum SearchError: Error {
    case invalidQuery
    case databaseError(Error)
    case notFound
}

queries.publisher
    .tryFirst(where: { query in
        guard query.count >= 3 else {
            throw SearchError.invalidQuery
        }
        let results = try database.search(query)
        return !results.isEmpty
    })
    .mapError { error -> SearchError in
        // tryFirst nới Failure → Error → thu hẹp về SearchError
        if let searchError = error as? SearchError {
            return searchError
        }
        return .databaseError(error)
    }
    .sink(
        receiveCompletion: { completion in
            switch completion {
            case .finished:
                print("No valid query found")
            case .failure(.invalidQuery):
                print("Query too short")
            case .failure(.databaseError(let underlying)):
                print("DB error: \(underlying)")
            case .failure(.notFound):
                print("Not found")
            }
        },
        receiveValue: { query in
            showResults(for: query)
        }
    )
    .store(in: &cancellables)
```

**Pattern chain:**

```
tryFirst(where:)    → Failure nới thành Error
    ↓
mapError            → Error thu hẹp thành SearchError
    ↓
sink                → switch exhaustive trên SearchError
```

---

## 8. Cancel Behavior — Giống first(where:)

`tryFirst(where:)` cancel upstream trong **cả 3 kịch bản kết thúc**:

```
Match (return true):   emit value → .finished → cancel upstream ✅
Throw:                 .failure(error) → cancel upstream ✅
Upstream complete:     forward .finished → (upstream đã complete) ✅
```

```swift
let subject = PassthroughSubject<Int, Never>()

subject
    .handleEvents(receiveCancel: { print("🛑 Cancelled") })
    .tryFirst(where: { value in
        guard value != 3 else { throw MyError.bad }
        return value > 5
    })
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
    .store(in: &cancellables)

subject.send(1)     // skip (1 > 5 = false)
subject.send(3)     // THROW → "Completion: failure(MyError.bad)"
                     //       → "🛑 Cancelled"
subject.send(10)    // không có hiệu lực — đã cancel
```

---

## 9. Kết hợp với operators khác

### + `retry` — Thử lại khi throw

```swift
// ⚠️ Cần Deferred nếu upstream là eager
Deferred {
    serverList.publisher
        .tryFirst(where: { url in
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        })
}
.retry(2)     // throw → thử lại từ đầu (tối đa 2 lần)
.sink(...)
```

### + `timeout` — Giới hạn thời gian tìm

```swift
eventStream
    .tryFirst(where: { event in
        try validateEvent(event)
        return event.type == .target
    })
    .timeout(.seconds(30), scheduler: RunLoop.main, customError: { .timedOut })
    .sink(...)
```

### + `replaceError` — Fallback khi throw

```swift
items.publisher
    .tryFirst(where: { try riskyCheck($0) })
    .replaceError(with: Item.default)    // throw → dùng default
    // Failure: Error → Never
    .sink(receiveValue: { item in use(item) })
```

---

## 10. Tóm tắt

| Khía cạnh | `first(where:)` | `tryFirst(where:)` |
|---|---|---|
| Closure | `(Value) -> Bool` | `(Value) throws -> Bool` |
| Throw? | ❌ Không | ✅ Có thể |
| Failure output | Giữ nguyên upstream | **Nới thành `Error`** |
| Khi throw | — | Pipeline fail ngay, cancel upstream |
| Khi match | Emit + complete + cancel | Emit + complete + cancel |
| Khi không match | Đợi upstream complete | Đợi upstream complete |
| Dùng khi | Check đơn giản (so sánh) | Check có thể fail (parse, I/O, decode) |
| Pattern sau đó | Dùng trực tiếp | + `mapError` để thu hẹp Error type |

-----

`tryFirst(where:)` là phiên bản **có thể throw** của `first(where:)`, Huy. Khác biệt cốt lõi nằm ở closure và Failure type:

**Closure có thể throw** — đây là lý do duy nhất dùng `tryFirst(where:)` thay vì `first(where:)`. Khi closure cần thực hiện operation có thể fail (parse JSON, đọc file, database query, network check), dùng `tryFirst(where:)`. Nếu chỉ so sánh property đơn giản (`$0 > 5`, `$0.isActive`) → dùng `first(where:)` là đủ.

**Failure nới thành `Error`** — giống mọi `try*` operator. Dù upstream có `Failure = Never`, sau `tryFirst(where:)` Failure thành `Error` protocol. Muốn exhaustive switch ở sink → chain thêm `.mapError { $0 as? MyError ?? .unknown }` để thu hẹp.

**Ba kịch bản kết thúc:** Closure return `true` → emit value + complete + cancel upstream (giống `first(where:)`). Closure `throw` → **pipeline fail ngay lập tức** + cancel upstream (value sau đó không bao giờ được kiểm tra). Upstream complete mà không match/throw → forward `.finished`, không emit value.

**Quyết định thiết kế quan trọng trong closure:** Dùng `throw` cho lỗi **nghiêm trọng** (data corrupt, parse fail) → pipeline dừng. Dùng `return false` cho item **không match nhưng không phải lỗi** (expired, inactive) → tiếp tục tìm item tiếp theo. Phân biệt đúng hai trường hợp này giúp pipeline behave chính xác.
