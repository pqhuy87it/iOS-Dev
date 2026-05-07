# Combine: `CombineLatest` — Giải thích chi tiết

## 1. Bản chất — Kết hợp value MỚI NHẤT từ nhiều Publisher

`CombineLatest` lắng nghe **nhiều publisher đồng thời**. Mỗi khi **bất kỳ publisher nào** emit value mới, nó gom value **mới nhất** từ **tất cả** publisher lại thành một tuple rồi phát xuống downstream.

```
Publisher A: ──a1────────a2──────────
Publisher B: ──────b1─────────b2─────
CombineLatest: ───(a1,b1)─(a2,b1)─(a2,b2)──
                    ↑        ↑        ↑
               B emit b1   A emit a2  B emit b2
               lần đầu     giữ b1     giữ a2
               cả 2 có     của B      của A
```

### Hai quy tắc cốt lõi

**Quy tắc 1: Đợi TẤT CẢ có value đầu tiên.** CombineLatest chỉ bắt đầu emit khi **mỗi publisher đã emit ít nhất 1 value**. Trước đó → im lặng.

**Quy tắc 2: Sau đó, bất kỳ ai thay đổi → emit combo mới nhất.** Giữ value cuối cùng của các publisher còn lại.

---

## 2. Minh hoạ chi tiết từng bước

```swift
let name = PassthroughSubject<String, Never>()
let age = PassthroughSubject<Int, Never>()

name.combineLatest(age)
    .sink { print("(\($0), \($1))") }
    .store(in: &cancellables)
```

```
Bước 1: name.send("Huy")
┌───────────────────────────────────┐
│ name latest = "Huy"               │
│ age latest  = ❌ (chưa có)        │
│ → KHÔNG emit (chưa đủ cả hai)    │
└───────────────────────────────────┘

Bước 2: age.send(25)
┌───────────────────────────────────┐
│ name latest = "Huy"               │
│ age latest  = 25      ← MỚI      │
│ → CẢ HAI đã có → emit ("Huy", 25)│
└───────────────────────────────────┘
Output: ("Huy", 25) ✅

Bước 3: name.send("John")
┌───────────────────────────────────┐
│ name latest = "John"  ← MỚI      │
│ age latest  = 25      (giữ nguyên)│
│ → emit ("John", 25)              │
└───────────────────────────────────┘
Output: ("John", 25) ✅

Bước 4: age.send(30)
┌───────────────────────────────────┐
│ name latest = "John"  (giữ nguyên)│
│ age latest  = 30      ← MỚI      │
│ → emit ("John", 30)              │
└───────────────────────────────────┘
Output: ("John", 30) ✅

Bước 5: name.send("Alice")
┌───────────────────────────────────┐
│ name latest = "Alice" ← MỚI      │
│ age latest  = 30      (giữ nguyên)│
│ → emit ("Alice", 30)             │
└───────────────────────────────────┘
Output: ("Alice", 30) ✅
```

---

## 3. Các cách sử dụng CombineLatest

### 3.1 Operator `.combineLatest()` — Chain trên publisher

```swift
// 2 publishers
publisherA
    .combineLatest(publisherB)
    .sink { a, b in ... }
// Output type: (A.Output, B.Output)

// 3 publishers
publisherA
    .combineLatest(publisherB, publisherC)
    .sink { a, b, c in ... }
// Output type: (A.Output, B.Output, C.Output)

// 2 publishers + transform ngay
publisherA
    .combineLatest(publisherB) { a, b in
        return a + b    // transform thành giá trị mới
    }
    .sink { sum in ... }
// Output type: transform return type
```

### 3.2 `Publishers.CombineLatest` — Static type

```swift
// 2 publishers
Publishers.CombineLatest(publisherA, publisherB)
    .sink { a, b in ... }

// 3 publishers
Publishers.CombineLatest3(publisherA, publisherB, publisherC)
    .sink { a, b, c in ... }

// 4 publishers (tối đa)
Publishers.CombineLatest4(publisherA, publisherB, publisherC, publisherD)
    .sink { a, b, c, d in ... }
```

### Nhiều hơn 4 publishers?

```swift
// Lồng CombineLatest
Publishers.CombineLatest4(pubA, pubB, pubC, pubD)
    .combineLatest(pubE)
    .sink { (abcd, e) in
        let (a, b, c, d) = abcd
        // Dùng a, b, c, d, e
    }

// Hoặc chain liên tiếp
pubA.combineLatest(pubB)
    .combineLatest(pubC)
    .combineLatest(pubD)
    .combineLatest(pubE)
    .map { ((((a, b), c), d), e) -> ... in
        // Nested tuples, cần destructure
    }
```

---

## 4. Ứng dụng kinh điển — Form Validation

### Bài toán

Form đăng ký cần validate: email hợp lệ, password đủ dài, confirm khớp password. Nút Submit chỉ enable khi **tất cả** điều kiện đúng **đồng thời**.

```swift
class SignUpViewModel: ObservableObject {
    // ── Input (từ UI) ──
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    
    // ── Output (cho UI) ──
    @Published private(set) var isEmailValid = false
    @Published private(set) var isPasswordValid = false
    @Published private(set) var doPasswordsMatch = false
    @Published private(set) var canSubmit = false
    
    init() {
        // Validate từng field riêng
        $email
            .map { $0.contains("@") && $0.contains(".") && $0.count >= 5 }
            .assign(to: &$isEmailValid)
        
        $password
            .map { $0.count >= 8 }
            .assign(to: &$isPasswordValid)
        
        Publishers.CombineLatest($password, $confirmPassword)
            .map { password, confirm in
                !password.isEmpty && password == confirm
            }
            .assign(to: &$doPasswordsMatch)
        
        // CombineLatest 3 điều kiện → canSubmit
        Publishers.CombineLatest3($isEmailValid, $isPasswordValid, $doPasswordsMatch)
            .map { emailOK, passOK, matchOK in
                emailOK && passOK && matchOK
            }
            .assign(to: &$canSubmit)
    }
}
```

### Tại sao CombineLatest phù hợp?

```
Kịch bản: User sửa email → cần re-evaluate canSubmit
nhưng password và confirmPassword KHÔNG thay đổi

$isEmailValid:      ──false──true──    ← thay đổi
$isPasswordValid:   ──true─────────    ← giữ nguyên
$doPasswordsMatch:  ──true─────────    ← giữ nguyên

CombineLatest3:     ──(false,true,true)──(true,true,true)──
                      ↑ canSubmit=false   ↑ canSubmit=true
                      
Chỉ email thay đổi nhưng CombineLatest dùng latest value
của password và match → đánh giá lại TOÀN BỘ form
```

### SwiftUI View

```swift
struct SignUpView: View {
    @StateObject private var vm = SignUpViewModel()
    
    var body: some View {
        Form {
            Section {
                TextField("Email", text: $vm.email)
                    .textContentType(.emailAddress)
                    .overlay(alignment: .trailing) {
                        Image(systemName: vm.isEmailValid ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(vm.isEmailValid ? .green : .red)
                    }
                
                SecureField("Password (8+ chars)", text: $vm.password)
                    .overlay(alignment: .trailing) {
                        Image(systemName: vm.isPasswordValid ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(vm.isPasswordValid ? .green : .red)
                    }
                
                SecureField("Confirm Password", text: $vm.confirmPassword)
                    .overlay(alignment: .trailing) {
                        Image(systemName: vm.doPasswordsMatch ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(vm.doPasswordsMatch ? .green : .red)
                    }
            }
            
            Button("Create Account") { vm.submit() }
                .disabled(!vm.canSubmit)
        }
    }
}
```

---

## 5. Ứng dụng thực tế khác

### 5.1 Search kết hợp filter

```swift
class ProductViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var selectedCategory: Category = .all
    @Published var sortOrder: SortOrder = .nameAsc
    @Published private(set) var products: [Product] = []
    
    private let allProducts: [Product]
    
    init(products: [Product]) {
        self.allProducts = products
        
        // Mỗi khi BẤT KỲ filter nào thay đổi → tính lại danh sách
        Publishers.CombineLatest3($searchQuery, $selectedCategory, $sortOrder)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .map { [allProducts] query, category, sort -> [Product] in
                var filtered = allProducts
                
                // Lọc theo category
                if category != .all {
                    filtered = filtered.filter { $0.category == category }
                }
                
                // Lọc theo search
                if !query.isEmpty {
                    filtered = filtered.filter {
                        $0.name.localizedCaseInsensitiveContains(query)
                    }
                }
                
                // Sắp xếp
                switch sort {
                case .nameAsc:  filtered.sort { $0.name < $1.name }
                case .nameDesc: filtered.sort { $0.name > $1.name }
                case .priceAsc: filtered.sort { $0.price < $1.price }
                case .priceDesc:filtered.sort { $0.price > $1.price }
                }
                
                return filtered
            }
            .assign(to: &$products)
    }
}
```

```
User đổi category sang "Electronics":

$searchQuery:       ──"phone"──────────    (giữ nguyên)
$selectedCategory:  ──.all──.electronics── (thay đổi)
$sortOrder:         ──.nameAsc─────────    (giữ nguyên)

CombineLatest3:     ──("phone",.all,.nameAsc)──("phone",.electronics,.nameAsc)──
                                                ↑ re-filter toàn bộ
```

### 5.2 Đợi nhiều API xong + state sẵn sàng

```swift
class DashboardViewModel: ObservableObject {
    @Published var selectedPeriod: Period = .week
    @Published private(set) var dashboard: DashboardData?
    @Published private(set) var isLoading = false
    
    private let userService: UserService
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    
    init(userService: UserService, analyticsService: AnalyticsService) {
        self.userService = userService
        self.analyticsService = analyticsService
        
        $selectedPeriod
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = true
            })
            .flatMap { [userService, analyticsService] period in
                // CombineLatest: đợi CẢ HAI API trả về
                userService.fetchProfile()
                    .combineLatest(analyticsService.fetchStats(period: period))
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("Error: \(error)")
                    }
                },
                receiveValue: { [weak self] user, stats in
                    self?.isLoading = false
                    self?.dashboard = DashboardData(user: user, stats: stats)
                }
            )
            .store(in: &cancellables)
    }
}
```

### 5.3 Settings liên kết nhau

```swift
class ThemeViewModel: ObservableObject {
    @Published var isDarkMode = false
    @Published var accentColorName = "blue"
    @Published var fontSize: CGFloat = 16
    @Published private(set) var theme = AppTheme.default
    
    init() {
        Publishers.CombineLatest3($isDarkMode, $accentColorName, $fontSize)
            .map { dark, colorName, size in
                AppTheme(
                    colorScheme: dark ? .dark : .light,
                    accentColor: Color(colorName),
                    fontSize: size
                )
            }
            .assign(to: &$theme)
        // Thay đổi BẤT KỲ setting → theme được build lại NGAY
    }
}
```

### 5.4 Authentication state + Network reachability

```swift
class AppStateViewModel: ObservableObject {
    @Published private(set) var canAccessContent = false
    
    private let authManager: AuthManager
    private let networkMonitor: NetworkMonitor
    
    init(authManager: AuthManager, networkMonitor: NetworkMonitor) {
        self.authManager = authManager
        self.networkMonitor = networkMonitor
        
        // Chỉ cho truy cập nội dung khi VỪA đăng nhập VỪA có mạng
        authManager.$isLoggedIn
            .combineLatest(networkMonitor.$isConnected)
            .map { isLoggedIn, isConnected in
                isLoggedIn && isConnected
            }
            .removeDuplicates()
            .assign(to: &$canAccessContent)
    }
}
```

---

## 6. Completion Behavior — Khi nào CombineLatest complete?

### Quy tắc

```
CombineLatest complete khi:
  1. TẤT CẢ upstream publishers đã complete (.finished)
  
CombineLatest fail khi:
  2. BẤT KỲ upstream publisher nào fail (.failure)
     → fail NGAY LẬP TỨC, cancel các publisher còn lại
```

### Minh hoạ

```swift
let a = PassthroughSubject<Int, Never>()
let b = PassthroughSubject<Int, Never>()

a.combineLatest(b)
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )
    .store(in: &cancellables)

a.send(1)                          // chờ b...
b.send(10)                         // Value: (1, 10)
a.send(completion: .finished)      // a xong, nhưng b chưa → chưa complete
b.send(20)                         // Value: (1, 20) ← a giữ value cuối = 1
b.send(completion: .finished)      // b cũng xong → Completion: finished
```

```
a:              ──1──────────|
b:              ──────10──────────20──|
combineLatest:  ──────(1,10)──────(1,20)──|
                                           ↑ complete khi CẢ HAI finished
```

**Publisher đã finished vẫn đóng góp latest value** cho combo. Chỉ là nó không phát value mới nữa.

### Với error

```swift
let a = PassthroughSubject<Int, MyError>()
let b = PassthroughSubject<Int, MyError>()

a.combineLatest(b)
    .sink(
        receiveCompletion: { print("Completion: \($0)") },
        receiveValue: { print("Value: \($0)") }
    )

a.send(1)
b.send(10)                                    // Value: (1, 10)
a.send(completion: .failure(.someError))       // Completion: failure(someError)
// → b bị cancel, pipeline chết ngay
b.send(20)                                     // ❌ Không có hiệu lực
```

---

## 7. CombineLatest vs Zip vs Merge

### So sánh trực quan

```swift
let a = PassthroughSubject<String, Never>()
let b = PassthroughSubject<Int, Never>()
```

```
a:       ──"X"──────"Y"──────
b:       ──────1──────────2──

CombineLatest:
         ──────("X",1)──("Y",1)──("Y",2)──
               ↑ đợi cả 2  ↑ a đổi    ↑ b đổi
               có value     giữ b=1    giữ a="Y"
               
Zip:
         ──────("X",1)──────────("Y",2)──
               ↑ ghép cặp 1-1    ↑ ghép cặp 2-2
               X với 1           Y với 2
               
Merge:   ❌ Không dùng được — Output type khác nhau (String vs Int)
         (Merge yêu cầu cùng Output type)
```

### Bảng so sánh

```
                CombineLatest              Zip                    Merge
                ─────────────              ───                    ─────
Emit khi?       Bất kỳ ai thay đổi        Cả 2 có value MỚI     Bất kỳ ai emit
                (sau khi tất cả đã có      (ghép cặp tuần tự)    (interleave)
                 ít nhất 1 value)

Output?         Tuple (A, B)               Tuple (A, B)           Cùng type A

Giữ value cũ?  ✅ Có (latest)             ❌ Không (1-1 matching) N/A

Số lượng emit  >= max(countA, countB)     = min(countA, countB)  = countA + countB

Output type    Có thể KHÁC nhau           Có thể KHÁC nhau      Phải CÙNG nhau
giữa publishers?

Dùng khi?      Kết hợp nhiều state        Đợi nhiều kết quả     Gộp nhiều
               "mỗi khi gì đổi →          "ghép cặp 1-1"        stream cùng type
               tính lại tất cả"
```

### Ví dụ phân biệt

```swift
// CombineLatest: Form validation
// "Mỗi khi user thay đổi BẤT KỲ field → validate lại TOÀN BỘ form"
$email.combineLatest($password)
    .map { email, pass in isValid(email, pass) }

// Zip: Đợi 2 API cùng xong
// "Tôi cần KẾT QUẢ CỦA CẢ HAI, ghép 1-1"
fetchUser().zip(fetchPosts())
    .sink { user, posts in display(user, posts) }

// Merge: Nhiều nguồn notification
// "Tôi muốn NGHE TẤT CẢ, không cần ghép"
appActive.merge(with: appBackground)
    .sink { event in handle(event) }
```

---

## 8. Kết hợp CombineLatest với các Operator khác

### + `removeDuplicates`: Tránh emit trùng

```swift
$email.combineLatest($password)
    .map { email, pass in email.contains("@") && pass.count >= 8 }
    .removeDuplicates()    // chỉ emit khi canSubmit THAY ĐỔI
    .assign(to: &$canSubmit)
// Không có removeDuplicates: gõ "a" → false, gõ "ab" → false (emit lại dù cùng giá trị)
// Có removeDuplicates: false chỉ emit 1 lần cho đến khi chuyển true
```

### + `debounce`: Tránh tính toán quá nhiều

```swift
Publishers.CombineLatest3($query, $category, $sortOrder)
    .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
    .map { query, category, sort in filterProducts(query, category, sort) }
    .assign(to: &$products)
// User thay đổi liên tục → debounce đợi 200ms yên lặng → tính 1 lần
```

### + `flatMap`: Trigger API khi input thay đổi

```swift
$city.combineLatest($date)
    .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
    .removeDuplicates { $0 == $1 }
    .map { city, date in
        weatherAPI.fetchForecast(city: city, date: date)
            .catch { _ in Just(Forecast.empty) }
    }
    .switchToLatest()    // cancel request cũ khi input mới
    .assign(to: &$forecast)
```

### + `filter`: Chỉ xử lý khi combo hợp lệ

```swift
$username.combineLatest($authToken)
    .filter { username, token in
        !username.isEmpty && !token.isEmpty    // chỉ xử lý khi cả hai có giá trị
    }
    .flatMap { username, token in
        api.fetchProfile(username: username, token: token)
    }
    .sink { ... }
```

---

## 9. Sai lầm thường gặp

### ❌ Sai lầm 1: Nhầm CombineLatest với Zip

```swift
// Muốn: đợi 2 API xong rồi dùng cả 2 kết quả
// ❌ CombineLatest — nếu 1 API trả về trước, sẽ emit cặp không đầy đủ
//    nếu API nào trả về nhiều value → emit combo mỗi lần
api.fetchUser().combineLatest(api.fetchSettings())

// ✅ Zip — ghép cặp 1-1, đợi cả 2 có kết quả
api.fetchUser().zip(api.fetchSettings())
    .sink { user, settings in ... }
```

Tuy nhiên, với one-shot publishers (Future, dataTaskPublisher), **CombineLatest và Zip cho kết quả giống nhau** vì mỗi publisher chỉ emit 1 value:

```
One-shot A: ──valueA──|
One-shot B: ──────valueB──|

CombineLatest: ──────(A,B)──|    ← giống nhau!
Zip:           ──────(A,B)──|    ← giống nhau!
```

Khác biệt chỉ rõ ràng khi publisher emit **nhiều value**.

### ❌ Sai lầm 2: Quên CombineLatest đợi TẤT CẢ

```swift
$searchQuery.combineLatest($selectedFilter)
    .sink { query, filter in
        self.search(query: query, filter: filter)
    }
// Nếu selectedFilter chưa emit → KHÔNG search
// Giải pháp: đảm bảo tất cả publisher có initial value
// @Published var selectedFilter: Filter = .all  ← có initial value ✅
```

`@Published` luôn có initial value → `CombineLatest` với `@Published` sẽ emit ngay lần đầu.

### ❌ Sai lầm 3: Quá nhiều emit không cần thiết

```swift
// User gõ "Hello" (5 ký tự) + filter không đổi
// → CombineLatest emit 5 lần, search 5 lần!

// ✅ Thêm debounce + removeDuplicates
$searchQuery.combineLatest($selectedFilter)
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates { $0 == $1 }
    .sink { ... }
```

---

## 10. Tóm tắt

| Khía cạnh | Chi tiết |
|---|---|
| **Là gì?** | Operator kết hợp value MỚI NHẤT từ nhiều publisher thành tuple |
| **Emit khi?** | Sau khi tất cả có ít nhất 1 value, mỗi khi BẤT KỲ publisher thay đổi |
| **Output type?** | Tuple `(A.Output, B.Output)` — output type có thể khác nhau |
| **Số lượng?** | CombineLatest (2), CombineLatest3 (3), CombineLatest4 (4), chain cho >4 |
| **Complete khi?** | TẤT CẢ upstream finished |
| **Fail khi?** | BẤT KỲ upstream fail → fail ngay |
| **Dùng khi?** | Form validation, multi-filter, combined state, settings |
| **Hay kết hợp với?** | `.debounce`, `.removeDuplicates`, `.map`, `.filter` |
| **Khác Zip?** | Zip ghép cặp 1-1 tuần tự. CombineLatest dùng latest, emit mỗi khi ai đổi |

----

`CombineLatest` là operator dùng nhiều nhất khi cần **kết hợp state từ nhiều nguồn**, Huy. Hai quy tắc cốt lõi cần nhớ:

**Quy tắc 1: Đợi tất cả.** CombineLatest im lặng cho đến khi **mọi publisher đều đã emit ít nhất 1 value**. Đây là lý do dùng với `@Published` rất thuận tiện — vì `@Published` luôn có initial value → CombineLatest emit ngay từ đầu.

**Quy tắc 2: Bất kỳ ai đổi → emit combo mới nhất.** Chỉ cần 1 publisher thay đổi, CombineLatest gom latest value của tất cả publisher còn lại thành tuple mới. Đây chính xác là behavior cần cho form validation: user sửa email → re-evaluate toàn bộ form dù password không đổi.

**Điểm hay bị nhầm với Zip:** Với one-shot publisher (API call trả 1 value), hai operator cho kết quả giống nhau. Khác biệt rõ khi publisher emit nhiều value — CombineLatest dùng latest value của mỗi bên, Zip ghép cặp 1-1 tuần tự. Quy tắc chọn: "kết hợp state" → CombineLatest, "đợi nhiều kết quả ghép cặp" → Zip.

**Tip thực tế:** gần như luôn kết hợp CombineLatest với `.debounce()` và `.removeDuplicates()` — vì mỗi khi bất kỳ input nào thay đổi đều trigger emit, dễ gây tính toán thừa.
