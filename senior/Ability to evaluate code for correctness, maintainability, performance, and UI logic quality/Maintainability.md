# Maintainability — Code có dễ sống chung lâu dài không?

Maintainability là khả năng code có thể được **đọc hiểu, sửa đổi, mở rộng, và debug** bởi bất kỳ ai trong team — kể cả chính mình 6 tháng sau khi đã quên hoàn toàn context. Senior iOS developer đánh giá maintainability qua nhiều tầng.

---

## 1. Readability — Đọc code như đọc văn bản

Code được viết một lần nhưng được đọc hàng trăm lần. Readability là nền tảng của maintainability.

### 1.1. Naming — Tên phải kể được câu chuyện

```swift
// ❌ Tên không nói lên điều gì
func process(_ d: [String: Any], _ f: Bool) -> Int
let x = calc(a, b)
let temp = arr.filter { $0.t > 0 }

// ✅ Tên tự giải thích — đọc xong biết ngay mục đích
func calculateShippingCost(for order: OrderDetails, applyDiscount: Bool) -> Decimal
let totalPrice = calculateSubtotal(items: cartItems, taxRate: taxRate)
let activeSubscriptions = subscriptions.filter { $0.expiresAt > Date() }
```

**Nguyên tắc cụ thể mà senior enforce:**

**Function** — bắt đầu bằng động từ, mô tả action: `fetchUserProfile()`, `validatePaymentInfo()`, `dismissOnboarding()`. Nếu return Bool, đọc như câu hỏi yes/no: `canProceedToCheckout()`, `isEligibleForTrial()`.

**Variable** — danh từ hoặc tính từ, mô tả "cái gì" chứ không phải "loại gì": `remainingAttempts` thay vì `intCount`, `selectedCategory` thay vì `categoryData`.

**Boolean** — luôn đọc được như mệnh đề đúng/sai: `isLoading`, `hasUnreadMessages`, `shouldRefreshOnAppear`. Tránh tên mập mờ như `flag`, `status`, `check`.

**Closure parameter** — tránh `$0` khi logic phức tạp:

```swift
// ❌ $0 trong chain dài — phải giữ mental model
let result = orders
    .filter { $0.status == .completed }
    .flatMap { $0.items }
    .filter { $0.price > 100 && $0.category != .digital }
    .sorted { $0.price > $1.price }

// ✅ Named parameter khi logic non-trivial
let result = orders
    .filter { order in order.status == .completed }
    .flatMap { order in order.items }
    .filter { item in item.price > 100 && item.category != .digital }
    .sorted { lhs, rhs in lhs.price > rhs.price }
```

### 1.2. Function Length & Complexity

Một function nên làm **một việc**, ở **một mức abstraction**. Senior sẽ flag ngay khi thấy function dài hơn 30-40 dòng hoặc cần scroll để đọc hết.

```swift
// ❌ "God function" — làm tất cả mọi thứ, không thể hiểu nhanh
func submitOrder() {
    // 20 dòng validate input...
    guard let name = nameField.text, !name.isEmpty else { ... }
    guard let email = emailField.text, email.contains("@") else { ... }
    guard let phone = phoneField.text, phone.count >= 10 else { ... }
    // ...thêm 10 trường nữa
    
    // 15 dòng build request...
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    let body: [String: Any] = ["name": name, "email": email, ...]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    // 20 dòng handle response...
    URLSession.shared.dataTask(with: request) { data, response, error in
        // parse JSON, handle errors, update UI, show alert...
    }
    
    // 10 dòng analytics tracking...
    Analytics.log("order_submitted", properties: [...])
    
    // 10 dòng update local state...
    cartItems.removeAll()
    UserDefaults.standard.set(Date(), forKey: "lastOrderDate")
}
```

```swift
// ✅ Mỗi function một việc, đọc submitOrder() như mục lục
func submitOrder() {
    do {
        let validatedInput = try validateOrderInput()
        let order = buildOrder(from: validatedInput)
        
        try await orderService.submit(order)
        
        trackOrderSubmitted(order)
        clearCart()
        showConfirmation(for: order)
    } catch {
        showError(error)
    }
}

// Mỗi sub-function nhỏ, dễ test riêng, dễ tìm bug
private func validateOrderInput() throws -> ValidatedOrderInput { ... }
private func buildOrder(from input: ValidatedOrderInput) -> Order { ... }
private func trackOrderSubmitted(_ order: Order) { ... }
private func clearCart() { ... }
```

### 1.3. Comments — Giải thích "tại sao", không phải "cái gì"

```swift
// ❌ Comment thừa — code đã tự nói rồi
// Set the user's name
user.name = newName

// Increment counter by 1
counter += 1

// ❌ Comment che đậy bad naming
// Check if user can buy alcohol
let f = u.a >= 21  // ???

// ✅ Comment giải thích "WHY" — context mà code không thể hiện được
// Apple rejects apps that request location permission without active use.
// We delay the permission prompt until the user taps "Find nearby stores"
// to satisfy App Review guideline 5.1.1.
locationManager.requestWhenInUseAuthorization()

// Server returns timestamps in seconds, but Date(timeIntervalSince1970:)
// expects seconds too — no conversion needed despite API docs saying "ms".
// Confirmed with backend team on 2025-01-15 (Slack thread #api-fixes).
let date = Date(timeIntervalSince1970: response.timestamp)

// Workaround: UITextView has a bug on iOS 16 where setting text
// programmatically doesn't trigger textViewDidChange delegate.
// Force-calling it ensures our character counter stays in sync.
// Radar: FB12345678
textViewDidChange(textView)
```

---

## 2. Single Responsibility Principle (SRP)

Một module/class/function chỉ nên có **một lý do để thay đổi**. Nếu bạn phải sửa một file vì thay đổi UI, và cũng phải sửa cùng file đó vì thay đổi business rule → file đó vi phạm SRP.

### Ví dụ điển hình: Massive ViewController

```swift
// ❌ ViewController đang làm 6 công việc khác nhau
class ProductDetailViewController: UIViewController,
    UITableViewDataSource, UITableViewDelegate,
    UIScrollViewDelegate, UIImagePickerControllerDelegate {
    
    // 1. UI Setup (layout, constraints)
    // 2. Network calls (fetch product, fetch reviews)
    // 3. JSON parsing
    // 4. Business logic (calculate discount, check inventory)
    // 5. Navigation (push to cart, present login)
    // 6. Analytics tracking
    
    // → File 800+ dòng
    // → Thay đổi cách tính discount? Sửa ViewController
    // → Thay đổi API endpoint? Sửa ViewController
    // → Thay đổi analytics tool? Sửa ViewController
    // → Mọi thay đổi đều conflict với nhau trong git
}
```

```swift
// ✅ Tách theo responsibility — mỗi component một lý do thay đổi

// Thay đổi business logic? → Sửa ViewModel
class ProductDetailViewModel {
    private let productService: ProductServiceProtocol
    private let pricingEngine: PricingEngineProtocol
    
    var displayPrice: String {
        pricingEngine.formatPrice(product.price, discount: currentDiscount)
    }
    
    var isAddToCartEnabled: Bool {
        product.inventory > 0 && !isLoading
    }
    
    func loadProduct() async { ... }
}

// Thay đổi API? → Sửa Service
class ProductService: ProductServiceProtocol {
    func fetchProduct(id: String) async throws -> Product { ... }
    func fetchReviews(productId: String) async throws -> [Review] { ... }
}

// Thay đổi UI? → Sửa ViewController (giờ chỉ còn UI binding)
class ProductDetailViewController: UIViewController {
    private let viewModel: ProductDetailViewModel
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }
    
    private func bindViewModel() {
        // Chỉ bind data từ ViewModel lên UI, không có logic nào khác
    }
}

// Thay đổi analytics? → Sửa Tracker
class ProductAnalyticsTracker {
    func trackProductViewed(_ product: Product) { ... }
    func trackAddToCart(_ product: Product, quantity: Int) { ... }
}
```

**Lợi ích thực tế:**
- Git conflict giảm mạnh vì các developer sửa file khác nhau
- Code review nhanh hơn vì diff nhỏ, tập trung
- Bug dễ locate hơn: bug về giá → chắc chắn ở `PricingEngine`, không cần đọc 800 dòng ViewController

---

## 3. Coupling — Mức độ phụ thuộc lẫn nhau

### 3.1. Tight Coupling — Thay đổi một chỗ, vỡ nhiều chỗ

```swift
// ❌ Tight coupling: ViewModel biết cụ thể dùng Alamofire
class ProfileViewModel {
    func loadProfile() {
        AF.request("https://api.myapp.com/v2/profile",
                   method: .get,
                   headers: ["Authorization": "Bearer \(TokenStore.shared.accessToken)"])
        .validate()
        .responseDecodable(of: Profile.self) { response in
            switch response.result {
            case .success(let profile):
                self.profile = profile
            case .failure(let error):
                self.error = error
            }
        }
    }
}

// Vấn đề:
// → Muốn đổi từ Alamofire sang URLSession? Sửa MỌI ViewModel
// → Muốn test? Phải mock Alamofire — cực kỳ phức tạp
// → Muốn thêm caching layer? Sửa từng ViewModel một
// → URL, headers hardcode → đổi API version phải find-and-replace toàn project
```

### 3.2. Loose Coupling qua Protocol Abstraction

```swift
// ✅ ViewModel chỉ biết "có ai đó fetch được Profile cho tôi"
protocol ProfileRepository {
    func fetchProfile() async throws -> Profile
    func updateProfile(_ profile: Profile) async throws -> Profile
}

class ProfileViewModel {
    private let repository: ProfileRepository
    
    init(repository: ProfileRepository) {
        self.repository = repository
    }
    
    func loadProfile() async {
        state = .loading
        do {
            let profile = try await repository.fetchProfile()
            state = .loaded(profile)
        } catch {
            state = .error(error)
        }
    }
}

// Production: dùng Alamofire, URLSession, hay gì cũng được
class RemoteProfileRepository: ProfileRepository {
    private let networkClient: NetworkClient
    
    func fetchProfile() async throws -> Profile {
        try await networkClient.request(.get, "/profile")
    }
}

// Test: không cần network, không cần mock phức tạp
class MockProfileRepository: ProfileRepository {
    var stubbedProfile: Profile?
    var stubbedError: Error?
    
    func fetchProfile() async throws -> Profile {
        if let error = stubbedError { throw error }
        return stubbedProfile!
    }
}

// Cache layer: thêm decorator, KHÔNG sửa ViewModel
class CachedProfileRepository: ProfileRepository {
    private let remote: ProfileRepository
    private let cache: CacheStore
    
    func fetchProfile() async throws -> Profile {
        if let cached: Profile = cache.get("profile") {
            return cached
        }
        let profile = try await remote.fetchProfile()
        cache.set("profile", value: profile)
        return profile
    }
}
```

**Đo coupling thực tế:** khi review code, senior tự hỏi *"nếu tôi thay thế hoàn toàn implementation của module X, bao nhiêu file cần sửa?"* Nếu câu trả lời là hơn 1 file → coupling quá cao.

---

## 4. Code Duplication — DRY nhưng đừng quá khô

### 4.1. Duplication rõ ràng — Phải eliminate

```swift
// ❌ Copy-paste logic giữa các screens
class OrderListViewController {
    func formatPrice(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? ""
    }
}

class CartViewController {
    func formatPrice(_ amount: Double) -> String {
        // ... copy-paste y hệt 🤦
        // → Mai đổi currency format, phải tìm sửa N chỗ
        // → Quên 1 chỗ = inconsistent UX
    }
}

// ✅ Centralize
extension Decimal {
    func formattedAsCurrency(_ code: String = "VND") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return formatter.string(from: self as NSDecimalNumber) ?? ""
    }
}
```

### 4.2. "Wrong DRY" — Gộp chung những thứ khác bản chất

Không phải code giống nhau nghĩa là nên gộp. Senior phải phân biệt **accidental duplication** vs **real duplication**:

```swift
// ❌ Over-DRY: gộp hai thứ "trông giống" nhưng bản chất khác
// Ban đầu OrderDTO và UserDTO tình cờ có cùng structure
struct GenericDTO {  // "tái sử dụng" cho cả Order lẫn User
    var id: String
    var name: String
    var metadata: [String: Any]
}

// 3 tháng sau: Order cần thêm `status`, `totalAmount`, `items`
// User cần thêm `email`, `avatar`, `role`
// → GenericDTO phình ra với đầy if-else, optional properties
// → Sửa cho Order break User và ngược lại
// → WORSE than duplication

// ✅ Giữ riêng — chúng evolve theo hướng khác nhau
struct OrderDTO: Codable {
    let id: String
    let name: String
    let status: OrderStatus
    let items: [OrderItem]
    let totalAmount: Decimal
}

struct UserDTO: Codable {
    let id: String
    let name: String
    let email: String
    let avatarURL: URL?
    let role: UserRole
}
```

**Quy tắc senior dùng để quyết định:** *"Nếu thay đổi ở use case A buộc phải thay đổi shared code theo cách ảnh hưởng use case B → đó là wrong abstraction. Tốt hơn là duplicate."* Hay nói theo Rule of Three: chỉ refactor khi thấy pattern lặp lại **ít nhất 3 lần** và business reason giống nhau.

---

## 5. Modular Architecture — Tổ chức code theo boundary rõ ràng

### 5.1. Folder by Feature, không phải Folder by Type

```
// ❌ Group by type — tìm file liên quan phải nhảy qua 5 folders
├── ViewControllers/
│   ├── LoginViewController.swift
│   ├── ProfileViewController.swift
│   ├── OrderViewController.swift
│   └── ... 30 files
├── ViewModels/
│   ├── LoginViewModel.swift
│   └── ... 30 files
├── Models/
│   ├── User.swift
│   └── ... 30 files
├── Services/
│   └── ... 20 files
├── Views/
│   └── ... 50 files

// ✅ Group by feature — mọi thứ liên quan nằm cạnh nhau
├── Features/
│   ├── Authentication/
│   │   ├── LoginView.swift
│   │   ├── LoginViewModel.swift
│   │   ├── AuthService.swift
│   │   ├── LoginValidator.swift
│   │   └── AuthModels.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   ├── ProfileViewModel.swift
│   │   ├── EditProfileView.swift
│   │   └── ProfileModels.swift
│   └── Orders/
│       └── ...
├── Core/
│   ├── Networking/
│   ├── Storage/
│   └── Extensions/
└── DesignSystem/
    ├── Components/
    └── Tokens/
```

### 5.2. SPM Module hóa trong large-scale project

```swift
// Package.swift — mỗi feature là một module riêng biệt
let package = Package(
    name: "MyApp",
    products: [...],
    targets: [
        // Core layer — không phụ thuộc feature nào
        .target(name: "Networking", dependencies: []),
        .target(name: "DesignSystem", dependencies: []),
        .target(name: "SharedModels", dependencies: []),
        
        // Feature modules — chỉ depend vào Core
        .target(name: "AuthFeature", dependencies: [
            "Networking", "DesignSystem", "SharedModels"
        ]),
        .target(name: "ProfileFeature", dependencies: [
            "Networking", "DesignSystem", "SharedModels"
        ]),
        .target(name: "OrderFeature", dependencies: [
            "Networking", "DesignSystem", "SharedModels"
        ]),
        
        // App shell — compose features together
        .target(name: "MyApp", dependencies: [
            "AuthFeature", "ProfileFeature", "OrderFeature"
        ]),
    ]
)
```

**Lợi ích khi module hóa:**
- **Compile time giảm mạnh**: sửa `ProfileFeature` → chỉ recompile module đó, không phải cả project
- **Enforce boundaries**: `AuthFeature` không thể import `OrderFeature` trực tiếp → buộc phải communicate qua protocol ở `SharedModels`
- **Onboarding dễ hơn**: dev mới chỉ cần hiểu module mình phụ trách
- **Parallel development**: hai team làm hai feature song song, gần như không conflict

---

## 6. Error Handling Strategy — Khi code fail, fail rõ ràng

### 6.1. Tránh silent failure

```swift
// ❌ Nuốt error — bug xảy ra nhưng không ai biết tại sao
func loadProfile() {
    do {
        let data = try fetchFromNetwork()
        let profile = try JSONDecoder().decode(Profile.self, from: data)
        self.profile = profile
    } catch {
        print(error) // chỉ log ra console, production user không thấy gì
        // UI vẫn hiển thị empty state — user không biết reload hay chờ
    }
}

// ❌ Dùng try? bừa bãi — che giấu root cause
let profile = try? JSONDecoder().decode(Profile.self, from: data)
// → data bị malformed? Server trả HTML thay JSON? Field name sai?
//   Không bao giờ biết được.
```

### 6.2. Typed Errors + Recovery Strategy

```swift
// ✅ Error có ngữ nghĩa rõ ràng, mỗi loại có recovery riêng
enum ProfileError: Error {
    case networkUnavailable
    case unauthorized          // token expired
    case serverError(statusCode: Int)
    case decodingFailed(field: String, underlying: Error)
    case notFound
}

class ProfileViewModel {
    @Published var state: ViewState<Profile> = .idle
    
    func loadProfile() async {
        state = .loading
        do {
            let profile = try await repository.fetchProfile()
            state = .loaded(profile)
        } catch let error as ProfileError {
            switch error {
            case .networkUnavailable:
                // Có cached version? Show stale data + banner "Offline"
                if let cached = cache.get("profile") {
                    state = .stale(cached, reason: .offline)
                } else {
                    state = .error(.retryable("No internet connection"))
                }
                
            case .unauthorized:
                // Redirect to login, don't show generic error
                state = .error(.requiresAuth)
                
            case .decodingFailed(let field, let underlying):
                // Log chi tiết để debug, show generic message cho user
                logger.error("Decode failed at '\(field)': \(underlying)")
                state = .error(.generic("Something went wrong"))
                
            case .serverError(let code):
                state = .error(.retryable("Server error (\(code))"))
                
            case .notFound:
                state = .error(.permanent("Profile not found"))
            }
        } catch {
            state = .error(.generic(error.localizedDescription))
        }
    }
}
```

---

## 7. Testability — Code có test được không?

Code khó test thường là dấu hiệu của design kém. Senior evaluate testability bằng cách tự hỏi: *"Tôi có thể viết unit test cho class này mà KHÔNG cần network, database, hay UI framework không?"*

### Hidden dependencies — Kẻ thù của testability

```swift
// ❌ Singleton + static calls — không thể thay thế khi test
class CheckoutViewModel {
    func calculateTotal() -> Decimal {
        let items = CartManager.shared.items          // singleton
        let user = UserSession.shared.currentUser     // singleton
        let rate = TaxService.getTaxRate(for: user.state)  // static call
        let now = Date()                               // hidden dependency
        
        var total = items.reduce(0) { $0 + $1.price }
        if Calendar.current.isDateInWeekend(now) {     // hidden: time dependency
            total *= 0.9  // weekend discount
        }
        total *= (1 + rate)
        return total
    }
    // Muốn test weekend discount? Phải chạy test vào cuối tuần (?!)
    // Muốn test tax calculation? Phải mock toàn bộ TaxService singleton
}

// ✅ Mọi dependency inject qua init — test control hoàn toàn
class CheckoutViewModel {
    private let cartRepository: CartRepositoryProtocol
    private let userSession: UserSessionProtocol
    private let taxService: TaxServiceProtocol
    private let dateProvider: () -> Date  // injectable time
    
    init(
        cartRepository: CartRepositoryProtocol,
        userSession: UserSessionProtocol,
        taxService: TaxServiceProtocol,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.cartRepository = cartRepository
        self.userSession = userSession
        self.taxService = taxService
        self.dateProvider = dateProvider
    }
    
    func calculateTotal() -> Decimal {
        let items = cartRepository.items
        let user = userSession.currentUser
        let rate = taxService.taxRate(for: user.state)
        let now = dateProvider()
        
        var total = items.reduce(0) { $0 + $1.price }
        if Calendar.current.isDateInWeekend(now) {
            total *= Decimal(string: "0.9")!
        }
        total *= (1 + rate)
        return total
    }
}

// Test: hoàn toàn deterministic
func testWeekendDiscount() {
    let saturday = makeDate("2025-03-22") // a Saturday
    let vm = CheckoutViewModel(
        cartRepository: MockCart(items: [.init(price: 100)]),
        userSession: MockSession(state: "CA"),
        taxService: MockTax(rate: 0.1),  // 10% tax
        dateProvider: { saturday }
    )
    
    let total = vm.calculateTotal()
    // 100 * 0.9 (weekend) * 1.1 (tax) = 99
    XCTAssertEqual(total, 99)
}

func testWeekdayNoDiscount() {
    let monday = makeDate("2025-03-24") // a Monday
    let vm = CheckoutViewModel(
        cartRepository: MockCart(items: [.init(price: 100)]),
        userSession: MockSession(state: "CA"),
        taxService: MockTax(rate: 0.1),
        dateProvider: { monday }
    )
    
    let total = vm.calculateTotal()
    // 100 * 1.1 (tax) = 110, no weekend discount
    XCTAssertEqual(total, 110)
}
```

---

## 8. API Surface — Public Interface càng nhỏ càng tốt

```swift
// ❌ Mọi thứ public — caller có thể phá internal state
class PaginationManager {
    public var currentPage = 0
    public var isLoading = false
    public var items: [Item] = []
    public var hasMore = true
    
    public func loadNext() { ... }
    public func reset() { ... }
    public func insertItem(_ item: Item, at index: Int) { ... }
    public func setLoading(_ value: Bool) { ... }
    
    // Caller có thể gọi: manager.currentPage = -5 → 💥
    // Caller có thể gọi: manager.isLoading = true rồi quên set false → stuck state
}

// ✅ Minimal public API — chỉ expose những gì caller CẦN
class PaginationManager<Item: Sendable> {
    // Read-only observation
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    
    // Chỉ 2 actions — caller không thể phá internal state
    func loadNextPage() async { ... }
    func reset() { ... }
    
    // currentPage, internal buffer, retry count... tất cả private
    private var currentPage = 0
    private var retryCount = 0
}
```

**Nguyên tắc:** class nên có **ít nhất có thể** public properties/methods. Mỗi public API là một "lời hứa" mà bạn phải maintain mãi mãi. `private(set)` cho phép observe nhưng không cho phép mutate từ ngoài.

---

## 9. Checklist Đánh Giá Maintainability Khi Code Review

Khi review PR, senior tự hỏi qua từng category:

**Readability** — tôi có hiểu đoạn code này trong 30 giây đầu tiên không? Nếu phải đọc lại 2-3 lần → naming hoặc structure có vấn đề.

**SRP** — file này có bao nhiêu lý do để thay đổi? Nếu nhiều hơn một → cần tách.

**Coupling** — nếu thay thế implementation của dependency X, bao nhiêu file phải sửa? Nếu nhiều hơn 1 → cần abstract qua protocol.

**Duplication** — logic này đã tồn tại ở đâu chưa? Nếu đang duplicate → extract. Nếu "trông giống" nhưng evolve theo hướng khác → giữ riêng.

**Error handling** — khi fail, caller có biết fail vì lý do gì không? Có recovery path rõ ràng không? Có silent failure nào bị nuốt không?

**Testability** — tôi có thể viết unit test cho function này trong 5 phút không? Nếu cần setup phức tạp → quá nhiều hidden dependencies.

**API Surface** — có property/method nào đang public mà không cần thiết không? Caller có thể đưa object vào invalid state qua public API không?

---

## Tổng kết

Maintainability không phải là một thuộc tính binary (có hoặc không), mà là một **phổ liên tục** mà senior liên tục cải thiện qua từng PR review. Cốt lõi nằm ở tư duy: code không chỉ cần "chạy đúng hôm nay" mà phải "an toàn khi sửa đổi vào ngày mai." Mọi quyết định design — từ cách đặt tên, cách tổ chức file, cách inject dependency, đến cách handle error — đều nên được đánh giá qua lăng kính: *"người tiếp theo đọc/sửa code này có dễ dàng hơn hay khó khăn hơn?"*
