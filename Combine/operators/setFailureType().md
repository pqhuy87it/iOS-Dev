# Combine: `setFailureType(to:)` — Giải thích chi tiết

## 1. Bản chất — Nâng Failure type từ `Never` lên type cụ thể

`setFailureType(to:)` là operator **chỉ thay đổi type ở compile-time**, không thay đổi bất kỳ behavior nào lúc runtime. Nó nói với compiler: "Publisher này hiện tại không thể fail (`Never`), nhưng hãy coi như nó CÓ THỂ fail với error type này."

```swift
Just("Hello")                              // <String, Never>
    .setFailureType(to: URLError.self)     // <String, URLError>
//                                            ↑ Failure đổi từ Never → URLError
//                                            ↑ KHÔNG có gì thay đổi lúc runtime
```

Tương tự việc cast trong Swift:

```swift
let x: Int = 42
let y: Int? = x      // "nâng" từ non-optional lên Optional
// Giá trị không đổi, chỉ type thay đổi
```

---

## 2. Vấn đề giải quyết — Type mismatch trong pipeline

### Combine yêu cầu Failure type khớp

Khi kết hợp nhiều publisher, Failure type phải **khớp nhau**. Publisher có `Failure = Never` không thể trực tiếp kết hợp với publisher có `Failure = Error`:

```swift
let namePublisher = Just("Huy")                    // <String, Never>
let networkPublisher = api.fetchProfile()           // <Profile, APIError>

// ❌ Compile error: Never ≠ APIError
namePublisher.combineLatest(networkPublisher)

// ❌ Compile error: Never ≠ APIError
namePublisher.merge(with: networkPublisher)

// ❌ Compile error: closure throw nhưng upstream là Never
Just("Hello")
    .tryMap { throw SomeError() }
// tryMap yêu cầu upstream có Failure tương thích
```

### setFailureType giải quyết type mismatch

```swift
let namePublisher = Just("Huy")
    .setFailureType(to: APIError.self)              // <String, APIError>

let networkPublisher = api.fetchProfile()           // <Profile, APIError>

// ✅ Cả hai đều <_, APIError> → combine được
namePublisher.combineLatest(networkPublisher)
    .sink(
        receiveCompletion: { ... },
        receiveValue: { name, profile in ... }
    )
```

---

## 3. Ràng buộc — Chỉ dùng khi Failure == Never

```swift
// ✅ Failure = Never → dùng được
Just(42).setFailureType(to: MyError.self)
[1, 2, 3].publisher.setFailureType(to: MyError.self)
$query.setFailureType(to: MyError.self)              // @Published → Never

// ❌ Failure ≠ Never → compile error
URLSession.shared.dataTaskPublisher(for: url)        // Failure = URLError
    .setFailureType(to: MyError.self)                // ❌ URLError ≠ Never
// Dùng .mapError thay thế khi Failure đã có type
```

```
Publisher có Failure = Never → setFailureType(to:) ✅
Publisher có Failure ≠ Never → mapError { } ✅ (chuyển đổi error type)
```

---

## 4. setFailureType vs mapError — Khi nào dùng cái nào

### `setFailureType` — Từ `Never` lên type cụ thể

```swift
// Input:  <String, Never>
// Output: <String, MyError>

Just("Hello")
    .setFailureType(to: MyError.self)
// Không có closure, không có logic
// Chỉ thay đổi type annotation
```

### `mapError` — Từ Error type A sang Error type B

```swift
// Input:  <Data, URLError>
// Output: <Data, AppError>

URLSession.shared.dataTaskPublisher(for: url)
    .mapError { urlError -> AppError in
        // Có closure: transform error thực sự
        switch urlError.code {
        case .notConnectedToInternet: return .offline
        case .timedOut: return .timeout
        default: return .network(urlError)
        }
    }
```

### Bảng so sánh

```
                    setFailureType              mapError
                    ──────────────              ────────
Input Failure       Never (bắt buộc)           Bất kỳ Error type
Output Failure      Type chỉ định              Type closure trả về
Có closure?         ❌ Không                    ✅ Có (transform logic)
Runtime behavior    Không thay đổi             Transform error thực sự
Khi nào?            Never → SomeError          ErrorA → ErrorB
```

---

## 5. Các tình huống thực tế

### 5.1 Kết hợp `Just` với network publisher

```swift
func fetchUserOrDefault(id: String?) -> AnyPublisher<User, APIError> {
    guard let id = id else {
        // Just có Failure = Never → cần nâng lên APIError
        return Just(User.guest)
            .setFailureType(to: APIError.self)
            .eraseToAnyPublisher()
    }
    
    return api.fetchUser(id: id)     // <User, APIError>
        .eraseToAnyPublisher()
    
    // Cả hai nhánh: AnyPublisher<User, APIError> ✅
}
```

Không có `setFailureType`:

```swift
return Just(User.guest)
    .eraseToAnyPublisher()
// Type: AnyPublisher<User, Never>  ← KHÁC AnyPublisher<User, APIError>
// ❌ Compile error khi return
```

### 5.2 `Empty` publisher với error type

```swift
func fetchData(shouldSkip: Bool) -> AnyPublisher<Data, NetworkError> {
    if shouldSkip {
        return Empty<Data, NetworkError>()
        // Empty cho phép chỉ định Failure trực tiếp trong generic
        // HOẶC:
        return Empty()
            .setFailureType(to: NetworkError.self)
            .eraseToAnyPublisher()
    }
    
    return networkService.fetch()
        .eraseToAnyPublisher()
}
```

### 5.3 Trước `tryMap` / `tryFilter`

```swift
// Just → Failure = Never
// tryMap → cần throw → Failure phải tương thích

Just("Hello")
    .tryMap { value -> Int in
        guard let num = Int(value) else {
            throw ParseError.invalidFormat
        }
        return num
    }
// ✅ Hoạt động: tryMap tự nới Failure thành Error

// Nhưng nếu muốn Failure CỤ THỂ hơn Error:
Just("Hello")
    .setFailureType(to: ParseError.self)     // <String, ParseError>
    .tryMap { value -> Int in
        guard let num = Int(value) else {
            throw ParseError.invalidFormat
        }
        return num
    }
    // ← tryMap nới thành Error
    .mapError { $0 as? ParseError ?? .unknown }
    // ← thu hẹp lại ParseError
```

### 5.4 CombineLatest với publishers có Failure khác nhau

```swift
class FormViewModel: ObservableObject {
    @Published var username = ""      // Published.Publisher: <String, Never>
    @Published var email = ""         // Published.Publisher: <String, Never>
    
    func validateForm() -> AnyPublisher<Bool, ValidationError> {
        let usernameValid = $username
            .setFailureType(to: ValidationError.self)
            // <String, Never> → <String, ValidationError>
            .tryMap { name -> Bool in
                guard name.count >= 3 else {
                    throw ValidationError.tooShort("username")
                }
                return true
            }
            .mapError { $0 as? ValidationError ?? .unknown }
        
        let emailValid = $email
            .setFailureType(to: ValidationError.self)
            .tryMap { email -> Bool in
                guard email.contains("@") else {
                    throw ValidationError.invalidEmail
                }
                return true
            }
            .mapError { $0 as? ValidationError ?? .unknown }
        
        // Giờ cả hai đều <Bool, ValidationError> → combineLatest được
        return usernameValid
            .combineLatest(emailValid)
            .map { $0 && $1 }
            .eraseToAnyPublisher()
    }
}
```

### 5.5 Merge publisher Never với publisher có Error

```swift
// Cached data (không fail) + Network data (có thể fail)
let cached = Just(cachedUsers)                     // <[User], Never>
    .setFailureType(to: NetworkError.self)         // <[User], NetworkError>

let network = api.fetchUsers()                     // <[User], NetworkError>

// Merge: emit cached ngay, rồi network khi có
cached
    .merge(with: network)                          // ✅ cùng <[User], NetworkError>
    .sink(
        receiveCompletion: { completion in
            if case .failure(let error) = completion {
                print("Network failed: \(error)")
            }
        },
        receiveValue: { users in
            self.users = users
        }
    )
    .store(in: &cancellables)
```

```
cached:  ──[cachedUsers]──|                        (ngay lập tức)
network: ──────────────────[freshUsers]──|          (sau vài giây)
merge:   ──[cachedUsers]──[freshUsers]──|
           ↑ hiện cached ngay    ↑ update với fresh data
```

### 5.6 FlatMap với fallback publisher

```swift
$searchQuery
    .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
    .removeDuplicates()
    .flatMap { [weak self] query -> AnyPublisher<[Item], APIError> in
        guard let self, !query.isEmpty else {
            // Just([]) có Failure = Never → cần nâng lên APIError
            return Just([Item]())
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
        return self.api.search(query: query)
            .eraseToAnyPublisher()
    }
    .sink(
        receiveCompletion: { ... },
        receiveValue: { [weak self] items in self?.results = items }
    )
    .store(in: &cancellables)
```

### 5.7 Protocol abstraction — Mock vs Real

```swift
protocol DataService {
    func fetch() -> AnyPublisher<[Item], ServiceError>
}

class RealService: DataService {
    func fetch() -> AnyPublisher<[Item], ServiceError> {
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [Item].self, decoder: JSONDecoder())
            .mapError { ServiceError.from($0) }
            .eraseToAnyPublisher()
    }
}

class MockService: DataService {
    func fetch() -> AnyPublisher<[Item], ServiceError> {
        // Just → Never → cần setFailureType để khớp protocol
        Just([Item.mock1, Item.mock2])
            .setFailureType(to: ServiceError.self)
            .eraseToAnyPublisher()
    }
}
```

---

## 6. Pattern phổ biến: `Just` + `setFailureType` + `eraseToAnyPublisher`

Đây là combo xuất hiện **rất thường xuyên** trong Combine code:

```swift
Just(defaultValue)
    .setFailureType(to: SomeError.self)
    .eraseToAnyPublisher()
```

Dùng khi cần trả về `AnyPublisher<T, SomeError>` nhưng giá trị đã có sẵn (không async, không fail):

```swift
func getUser(id: String?) -> AnyPublisher<User, AppError> {
    guard let id else {
        return Just(User.anonymous)                    // <User, Never>
            .setFailureType(to: AppError.self)         // <User, AppError>
            .eraseToAnyPublisher()                     // AnyPublisher<User, AppError>
    }
    return api.fetchUser(id: id).eraseToAnyPublisher() // AnyPublisher<User, AppError>
}
```

Thay thế: `Fail` khi muốn trả error thay vì value:

```swift
func getUser(id: String?) -> AnyPublisher<User, AppError> {
    guard let id else {
        return Fail(error: AppError.missingID)         // <User, AppError>
            .eraseToAnyPublisher()
    }
    return api.fetchUser(id: id).eraseToAnyPublisher()
}
```

---

## 7. Compiler perspective — Tại sao không tự suy ra?

### Swift type system là strict

```swift
// Swift không tự chuyển Never thành SomeError
// Dù Never là "bottom type" (subtype của mọi type về mặt lý thuyết)

let a: AnyPublisher<Int, Never> = Just(1).eraseToAnyPublisher()
let b: AnyPublisher<Int, MyError> = a    // ❌ Never ≠ MyError

// Phải tường minh:
let b: AnyPublisher<Int, MyError> = a
    .setFailureType(to: MyError.self)
    .eraseToAnyPublisher()               // ✅
```

### Type safety: đảm bảo developer ý thức về error handling

Việc bắt buộc `setFailureType` là **có chủ đích** — compiler muốn developer biết rõ: "publisher này đang chuyển từ 'không fail' sang 'có thể fail với error type X'". Đây là điểm mà error handling cần được xem xét.

---

## 8. Bên trong setFailureType — Không làm gì cả

```swift
// Đơn giản hoá implementation:
extension Publisher where Failure == Never {
    func setFailureType<E: Error>(to errorType: E.Type) -> Publishers.SetFailureType<Self, E> {
        Publishers.SetFailureType(upstream: self)
    }
}

struct SetFailureType<Upstream: Publisher, Failure: Error>: Publisher
    where Upstream.Failure == Never {
    
    typealias Output = Upstream.Output
    // Failure = generic parameter (không phải Never nữa)
    
    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        // Chỉ forward subscription — KHÔNG transform gì
        upstream
            .setFailureType(to: Failure.self)  // type-level only
            .subscribe(subscriber)
    }
}
```

**Zero runtime overhead** — không có logic transform, không có branching, chỉ thay đổi type signature.

---

## 9. Sai lầm thường gặp

### ❌ Dùng setFailureType khi Failure ≠ Never

```swift
URLSession.shared.dataTaskPublisher(for: url)    // Failure = URLError
    .setFailureType(to: AppError.self)           // ❌ Compile error
// setFailureType CHỈ dùng khi Failure == Never

// ✅ Dùng mapError
    .mapError { AppError.network($0) }           // URLError → AppError
```

### ❌ Nghĩ setFailureType "bảo vệ" khỏi error

```swift
Just("Hello")
    .setFailureType(to: MyError.self)
// ← Không có nghĩa "nếu có lỗi thì wrap thành MyError"
// ← CHỈ thay đổi TYPE, Just vẫn KHÔNG BAO GIỜ fail
// ← Mục đích: khớp type với publisher khác trong pipeline
```

### ❌ setFailureType sau tryMap

```swift
Just("Hello")
    .tryMap { try riskyOperation($0) }     // Failure = Error (đã nới)
    .setFailureType(to: MyError.self)      // ❌ Compile error: Error ≠ Never

// ✅ Đúng thứ tự: setFailureType TRƯỚC tryMap, hoặc mapError SAU tryMap
Just("Hello")
    .setFailureType(to: MyError.self)      // Never → MyError
    .tryMap { try riskyOperation($0) }      // MyError → Error (nới)
    .mapError { $0 as? MyError ?? .unknown } // Error → MyError (thu hẹp)
```

---

## 10. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Operator nâng Failure type từ `Never` lên type cụ thể |
| **Runtime behavior** | KHÔNG thay đổi — zero overhead, chỉ compile-time |
| **Ràng buộc** | Chỉ dùng khi `Failure == Never` |
| **Dùng khi** | Kết hợp publisher Never với publisher có Error (combineLatest, merge, flatMap, return type) |
| **Pattern phổ biến** | `Just(value).setFailureType(to: E.self).eraseToAnyPublisher()` |
| **vs mapError** | setFailureType: Never → E (chỉ type). mapError: ErrorA → ErrorB (có transform logic) |
| **Thứ tự** | Đặt TRƯỚC tryMap/tryFilter. Sau tryMap dùng mapError |

----

`setFailureType(to:)` là operator **chỉ thay đổi type, không thay đổi behavior**, Huy. Ba điểm cốt lõi:

**Vấn đề giải quyết:** Combine yêu cầu Failure type khớp khi kết hợp publishers. `Just`, `[].publisher`, `@Published` đều có `Failure = Never`. Khi muốn `combineLatest`, `merge`, hay return cùng type với publisher có error (như `URLSession`) → type mismatch → compile error. `setFailureType` "nâng" `Never` lên error type cần thiết.

**Zero runtime overhead:** Không có closure, không có logic — compiler chỉ thay đổi type annotation. `Just("Hello")` vẫn không bao giờ fail, `setFailureType(to: MyError.self)` chỉ nói compiler "hãy coi Failure là `MyError`" để khớp với publisher khác trong pipeline.

**Chỉ dùng khi `Failure == Never`:** Đây là ràng buộc cứng. Nếu publisher đã có Failure type (như `URLError`) → dùng `mapError` thay thế (có closure transform thực sự). Hai operator bổ trợ nhau: `setFailureType` cho `Never → SomeError`, `mapError` cho `ErrorA → ErrorB`.

Pattern xuất hiện rất thường xuyên trong production: `Just(defaultValue).setFailureType(to: SomeError.self).eraseToAnyPublisher()` — dùng khi function trả `AnyPublisher<T, SomeError>` nhưng một nhánh chỉ trả giá trị có sẵn (guard else, fallback, mock service).
