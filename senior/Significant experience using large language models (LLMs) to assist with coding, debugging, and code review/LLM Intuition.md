## LLM Intuition cho Senior iOS Developer — Biết khi nào tin, khi nào không

### 1. Tại sao cần "intuition" này?

Không có tài liệu nào nói "LLM chính xác 73% khi viết Combine pipeline" hay "LLM sai 40% khi xử lý Actor isolation". Intuition này đến từ **hàng trăm lần tương tác**, quan sát pattern nào LLM trả lời đúng, pattern nào luôn cần sửa. Đây là meta-skill quan trọng nhất khi dùng LLM — nó quyết định bạn tiết kiệm thời gian hay tốn thêm thời gian debug code do AI sinh ra.

---

### 2. LLM GIỎI: Những thứ nên delegate

#### a) Boilerplate code — Điểm mạnh lớn nhất

Boilerplate là code có cấu trúc lặp lại, ít logic phức tạp. LLM cực kỳ mạnh ở đây vì pattern rõ ràng, xuất hiện nhiều trong training data.

```swift
// ✅ LLM generate rất tốt: VIPER module boilerplate
// Chỉ cần nói: "Generate VIPER module for UserProfile"

// --- UserProfileProtocols.swift ---
protocol UserProfileViewProtocol: AnyObject {
    var presenter: UserProfilePresenterProtocol? { get set }
    func showProfile(_ viewModel: UserProfileViewModel)
    func showError(_ message: String)
    func showLoading()
    func hideLoading()
}

protocol UserProfilePresenterProtocol: AnyObject {
    var view: UserProfileViewProtocol? { get set }
    var interactor: UserProfileInteractorInputProtocol? { get set }
    var router: UserProfileRouterProtocol? { get set }
    func viewDidLoad()
    func didTapEditProfile()
    func didTapFollowButton()
}

protocol UserProfileInteractorInputProtocol: AnyObject {
    var presenter: UserProfileInteractorOutputProtocol? { get set }
    func fetchProfile(userId: String)
    func toggleFollow(userId: String)
}

protocol UserProfileInteractorOutputProtocol: AnyObject {
    func didFetchProfile(_ profile: UserProfile)
    func didFailFetchProfile(_ error: Error)
    func didToggleFollow(isFollowing: Bool)
}

protocol UserProfileRouterProtocol: AnyObject {
    static func createModule(userId: String) -> UIViewController
    func navigateToEditProfile(from view: UserProfileViewProtocol)
    func navigateToFollowersList(from view: UserProfileViewProtocol)
}

// --- UserProfilePresenter.swift ---
final class UserProfilePresenter: UserProfilePresenterProtocol {
    weak var view: UserProfileViewProtocol?
    var interactor: UserProfileInteractorInputProtocol?
    var router: UserProfileRouterProtocol?
    
    func viewDidLoad() {
        view?.showLoading()
        interactor?.fetchProfile(userId: userId)
    }
    
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    func didTapEditProfile() {
        router?.navigateToEditProfile(from: view!)
    }
    
    func didTapFollowButton() {
        interactor?.toggleFollow(userId: userId)
    }
}

extension UserProfilePresenter: UserProfileInteractorOutputProtocol {
    func didFetchProfile(_ profile: UserProfile) {
        view?.hideLoading()
        let viewModel = UserProfileViewModel(profile: profile)
        view?.showProfile(viewModel)
    }
    
    func didFailFetchProfile(_ error: Error) {
        view?.hideLoading()
        view?.showError(error.localizedDescription)
    }
    
    func didToggleFollow(isFollowing: Bool) {
        // update UI
    }
}

// LLM generate 5 files VIPER trong 30 giây
// Tay viết: 30-45 phút boilerplate
// Accuracy: ~95% — chỉ cần tweak nhỏ
```

```swift
// ✅ LLM generate rất tốt: Codable models từ JSON
// Paste JSON → nhận Swift struct ngay

// Input JSON:
// {
//   "user_id": "abc123",
//   "display_name": "Huy",
//   "avatar_url": "https://...",
//   "stats": { "followers": 1200, "following": 340 },
//   "is_verified": true,
//   "created_at": "2024-01-15T08:30:00Z"
// }

struct UserResponse: Codable {
    let userId: String
    let displayName: String
    let avatarUrl: String
    let stats: Stats
    let isVerified: Bool
    let createdAt: Date
    
    struct Stats: Codable {
        let followers: Int
        let following: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case stats
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }
}

// LLM generate CodingKeys, nested structs, Date handling
// chính xác gần 100% cho JSON đơn giản
```

```swift
// ✅ LLM generate rất tốt: Extension utilities
// "Write a UIColor extension for hex string initialization"
// "Write a Date extension for relative time display"
// "Write a String extension for email validation"
// → Đã có hàng triệu ví dụ trên Internet, LLM nhớ hết

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}
```

**Tại sao LLM giỏi boilerplate?** Vì boilerplate là pattern repetition — hàng triệu developer đã viết đúng cùng pattern này trên GitHub, StackOverflow, blogs. LLM chỉ cần "recall" pattern phổ biến nhất. Không cần reasoning phức tạp.

#### b) Pattern matching — Nhận diện và áp dụng design pattern

```swift
// ✅ "Convert this callback-based API to async/await"
// LLM rất giỏi vì đây là mechanical transformation

// Before: callback
func fetchUser(
    id: String, 
    completion: @escaping (Result<User, Error>) -> Void
) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error {
            completion(.failure(error))
            return
        }
        guard let data else {
            completion(.failure(APIError.noData))
            return
        }
        do {
            let user = try JSONDecoder().decode(User.self, from: data)
            completion(.success(user))
        } catch {
            completion(.failure(error))
        }
    }.resume()
}

// After: LLM converts perfectly
func fetchUser(id: String) async throws -> User {
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(User.self, from: data)
}

// ✅ Wrap legacy callback cho backward compatibility
func fetchUser(
    id: String, 
    completion: @escaping (Result<User, Error>) -> Void
) {
    Task {
        do {
            let user = try await fetchUser(id: id)
            completion(.success(user))
        } catch {
            completion(.failure(error))
        }
    }
}
```

```swift
// ✅ "Apply Builder pattern for complex object construction"
// LLM áp dụng design pattern chuẩn textbook

final class NetworkRequestBuilder {
    private var path: String = ""
    private var method: HTTPMethod = .get
    private var headers: [String: String] = [:]
    private var queryItems: [URLQueryItem] = []
    private var body: Data?
    private var timeout: TimeInterval = 30
    private var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    
    func setPath(_ path: String) -> NetworkRequestBuilder {
        self.path = path
        return self
    }
    
    func setMethod(_ method: HTTPMethod) -> NetworkRequestBuilder {
        self.method = method
        return self
    }
    
    func addHeader(_ key: String, value: String) -> NetworkRequestBuilder {
        headers[key] = value
        return self
    }
    
    func addQueryItem(name: String, value: String?) -> NetworkRequestBuilder {
        queryItems.append(URLQueryItem(name: name, value: value))
        return self
    }
    
    func setBody<T: Encodable>(_ body: T) throws -> NetworkRequestBuilder {
        self.body = try JSONEncoder().encode(body)
        return self
    }
    
    func build(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.timeoutInterval = timeout
        request.cachePolicy = cachePolicy
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}
```

**Tại sao LLM giỏi pattern matching?** Vì design patterns là "chuẩn hoá" — Gang of Four, Protocol-Oriented Programming, MVVM... đều có canonical form. LLM nhận diện "đây là Builder pattern" rồi apply template, giống như fill-in-the-blank.

#### c) Giải thích concept — Dùng LLM như reference book

```swift
// ✅ "Explain the difference between weak, unowned, 
//     and unowned(unsafe)"
// LLM giải thích rất tốt vì đây là kiến thức canonical

// ✅ "What happens when I capture self in a Task {}"
// LLM trả lời chính xác: Task captures self strongly,
// nhưng vì Task is structured (within function scope), 
// nó tự release khi task completes

// ✅ "Explain Sendable and @Sendable closures"
// LLM giải thích concept + ví dụ chuẩn

// ✅ "What's the difference between 
//     MainActor.run {} and @MainActor?"
// LLM biết: MainActor.run là hop-to-main-actor,
// @MainActor là declare entire function/class runs on main
```

**Tại sao?** Đây là factual knowledge đã được viết đi viết lại hàng nghìn lần trong documentation, WWDC sessions, blogs. LLM hoạt động như một cuốn encyclopedia cực kỳ tốt.

---

### 3. LLM KÉM: Những thứ phải tự làm hoặc review rất kỹ

#### a) Complex state management — LLM không hiểu "flow" của app

```swift
// ❌ Scenario: Shopping cart với discount rules
// 
// Business rules:
// 1. Nếu cart > 500k VND → free shipping
// 2. Nếu user là Premium → thêm 10% discount
// 3. Discount code chỉ áp dụng 1 lần / user
// 4. Nếu đã dùng discount code → không stack với 
//    Premium discount
// 5. Flash sale items không được áp discount
// 6. Khi remove item cuối cùng được free shipping 
//    → recalculate shipping fee
// 7. Cart expire sau 30 phút inactive → restore 
//    từ server
// 8. Optimistic UI: update cart UI ngay, rollback 
//    nếu server reject

// LLM sẽ viết CartViewModel khá hợp lý cho rules 1-3
// Nhưng khi bạn hỏi về interaction giữa 3-4-5-6-7-8:
// → LLM BẮT ĐẦU SAI

// Ví dụ LLM thường sai:
@Observable
final class CartViewModel {
    var items: [CartItem] = []
    var discountCode: String?
    var isPremium: Bool
    
    var totalPrice: Decimal {
        let subtotal = items.reduce(0) { $0 + $1.price * Decimal($1.quantity) }
        
        // ❌ LLM thường tính discount SAI khi rules interact
        var discount: Decimal = 0
        
        if let code = discountCode {
            // ❌ LLM quên check: user đã dùng code này chưa?
            // ❌ LLM quên check: flash sale items excluded
            discount += subtotal * 0.15
        }
        
        if isPremium && discountCode == nil {
            // ✅ LLM nhớ rule 4 nếu bạn nói rõ
            // ❌ Nhưng quên: premium discount cũng không áp 
            //    cho flash sale items
            discount += subtotal * 0.10
        }
        
        return subtotal - discount
        // ❌ Hoàn toàn quên shipping fee calculation
        // ❌ Quên edge case: discount > subtotal → negative?
    }
    
    func removeItem(_ item: CartItem) {
        items.removeAll { $0.id == item.id }
        // ❌ LLM quên: recalculate shipping khi 
        //    total drops below 500k
        // ❌ LLM quên: optimistic UI + rollback
        // ❌ LLM quên: cart expiry timer reset
    }
}

// ✅ SENIOR DEV VIẾT:
// Tách thành PricingEngine (pure function, dễ test)
// + CartStateManager (side effects, timer, server sync)
// + OptimisticUpdateManager (rollback queue)
// → 3 components nhỏ, mỗi cái LLM có thể giúp
// → Nhưng CÁCH TÁCH và INTERACTION chỉ senior hiểu
```

**Tại sao LLM kém?** State management phức tạp không phải về syntax — mà về **interaction giữa nhiều business rules**. LLM xử lý từng rule riêng lẻ OK, nhưng khi 8 rules tương tác với nhau, nó thiếu khả năng reasoning về combinatorial explosion. LLM cũng không nhớ "context" của toàn bộ app — nó chỉ thấy code trong prompt hiện tại.

#### b) Concurrency bugs đặc thù iOS — LLM nhìn code đúng nhưng runtime sai

```swift
// ❌ BUG 1: Actor reentrancy — LLM hầu như không biết
actor ImageCache {
    private var cache: [URL: UIImage] = [:]
    private var inProgress: [URL: Task<UIImage, Error>] = [:]
    
    func image(for url: URL) async throws -> UIImage {
        // Check cache
        if let cached = cache[url] {
            return cached
        }
        
        // Check if already downloading
        if let existing = inProgress[url] {
            return try await existing.value
        }
        
        // Start download
        let task = Task {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                throw ImageError.invalidData
            }
            return image
        }
        
        inProgress[url] = task
        
        // ❌ REENTRANCY BUG mà LLM không detect:
        // Sau `await task.value`, actor có thể đã bị 
        // suspend và reenter
        // → Một caller khác có thể đã modify cache/inProgress
        // → `inProgress[url] = nil` có thể xoá task 
        //    của request KHÁC
        let image = try await task.value
        
        cache[url] = image
        inProgress[url] = nil  // ❌ Race condition!
        
        return image
    }
}

// ✅ SENIOR DEV FIX: check lại state sau mỗi await
actor ImageCache {
    private var cache: [URL: UIImage] = [:]
    private var inProgress: [URL: Task<UIImage, Error>] = [:]
    
    func image(for url: URL) async throws -> UIImage {
        if let cached = cache[url] { return cached }
        if let existing = inProgress[url] { 
            return try await existing.value 
        }
        
        let task = Task {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                throw ImageError.invalidData
            }
            return image
        }
        inProgress[url] = task
        
        do {
            let image = try await task.value
            // Re-check: có thể ai đó đã cache trong lúc await
            if cache[url] == nil {
                cache[url] = image
            }
            // Chỉ xoá nếu task hiện tại vẫn là task ta tạo
            if inProgress[url] === task {
                inProgress[url] = nil
            }
            return cache[url] ?? image
        } catch {
            if inProgress[url] === task {
                inProgress[url] = nil
            }
            throw error
        }
    }
}
```

```swift
// ❌ BUG 2: Main thread violation ẩn 
// — LLM generate code nhìn đúng nhưng crash
final class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var error: String?
    
    private let repository: UserRepository
    
    func loadProfile() {
        Task {
            do {
                let user = try await repository.fetchUser()
                // ❌ LLM hay quên: @Published update 
                //    PHẢI trên Main thread
                // Nhìn code đúng, nhưng crash khi:
                // - repository.fetchUser() return 
                //   trên background thread
                // - iOS 17 strict concurrency checking = error
                self.user = user  // ⚠️ potential crash
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// LLM có thể thêm @MainActor cho func loadProfile()
// Nhưng không hiểu implication:
// → Nếu fetchUser() heavy computation → block main thread
// → Cần @MainActor chỉ cho phần update UI, 
//   không phải toàn bộ function

// ✅ SENIOR DEV:
func loadProfile() {
    Task {
        do {
            // Fetch trên background (implicit)
            let user = try await repository.fetchUser()
            // Chỉ hop sang main cho UI update
            await MainActor.run {
                self.user = user
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
}

// Hoặc mark class @MainActor và đảm bảo 
// repository isolate heavy work
```

```swift
// ❌ BUG 3: Retain cycle trong Combine — LLM rất hay tạo
class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [SearchResult] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let searchService: SearchService
    
    init(searchService: SearchService) {
        self.searchService = searchService
        setupBindings()
    }
    
    private func setupBindings() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .flatMap { query in
                // ❌ LLM generate — retain cycle ẩn!
                // self bị capture strongly trong flatMap
                self.searchService.search(query: query)
                    .catch { _ in Just([]) }
            }
            .sink { results in
                // ❌ Lại capture self!
                self.results = results
            }
            .store(in: &cancellables)
        
        // ❌ ISSUE: self → cancellables → subscription 
        //    → closure → self
        // → ViewModel KHÔNG BAO GIỜ dealloc
        // → Memory leak
    }
}

// ✅ SENIOR DEV FIX:
private func setupBindings() {
    $query
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .removeDuplicates()
        .filter { !$0.isEmpty }
        .flatMap { [searchService] query in
            // Capture service trực tiếp, không capture self
            searchService.search(query: query)
                .catch { _ in Just([]) }
        }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] results in
            self?.results = results
        }
        .store(in: &cancellables)
}
```

```swift
// ❌ BUG 4: Data race với @Sendable — LLM không check
class AnalyticsTracker {
    // ❌ var mutable state, không thread-safe
    private var events: [AnalyticsEvent] = []
    
    func track(_ event: AnalyticsEvent) {
        events.append(event)  // ❌ Data race nếu gọi từ nhiều thread
    }
    
    func flush() async {
        // ❌ Đọc events trong khi thread khác 
        //    có thể đang append
        let batch = events
        events.removeAll()
        try? await uploadService.send(batch)
    }
}

// LLM sẽ generate class này mà không hề cảnh báo 
// data race
// Strict Concurrency trong Swift 6 sẽ catch — 
// nhưng nhiều project chưa enable

// ✅ SENIOR DEV: dùng actor hoặc serial queue
actor AnalyticsTracker {
    private var events: [AnalyticsEvent] = []
    
    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
    
    func flush() async {
        let batch = events
        events.removeAll()
        // nonisolated upload để không block actor
        try? await uploadService.send(batch)
    }
}
```

**Tại sao LLM kém ở concurrency?** Vì concurrency bugs là về **runtime behavior**, không phải syntax. Code trông hoàn toàn hợp lệ khi đọc — compiler cũng không báo lỗi (trước Swift 6). LLM "đọc code" giống cách nó đọc text: tuần tự, từ trên xuống dưới. Nó không simulate được "thread A đang ở dòng 5 trong khi thread B đang ở dòng 8". Actor reentrancy đặc biệt tricky vì ngay cả developer có kinh nghiệm cũng dễ miss.

#### c) Business logic cụ thể — LLM không có context

```swift
// ❌ SCENARIO: Fintech app — Transfer money
// 
// LLM KHÔNG THỂ BIẾT:
//
// 1. Regulatory requirement: transfer > 10 triệu VND 
//    cần OTP + face ID (NHNN regulation)
//    → LLM sẽ chỉ check amount > limit → show confirm
//    → Quên: OTP có expiry 60s, face ID fallback 
//      sang PIN, retry limit 3 lần rồi lock 24h
//
// 2. Business rule: transfer giữa 23:00-01:00 
//    chỉ pending, không process ngay
//    (bank settlement window)
//    → LLM không biết settlement schedule
//
// 3. UX requirement: khi transfer fail giữa chừng, 
//    KHÔNG show generic error
//    → Show specific: "Số dư không đủ" vs 
//      "Tài khoản người nhận không tồn tại" vs 
//      "Vượt hạn mức chuyển tiền trong ngày"
//    → Mỗi error có CTA khác nhau
//    → LLM sẽ show alert generic
//
// 4. Analytics requirement: track TỪNG BƯỚC 
//    trong transfer flow
//    → transfer_started, amount_entered, 
//      recipient_selected, otp_requested, otp_verified,
//      biometric_passed, transfer_confirmed, 
//      transfer_succeeded, transfer_failed
//    → Mỗi event có specific properties mà PM define
//    → LLM không biết event schema
//
// 5. A/B test: team đang test 2 flow khác nhau
//    → Variant A: confirm screen → biometric → done
//    → Variant B: biometric → confirm screen → done  
//    → LLM không biết experiment đang chạy

// Khi bạn nhờ LLM viết TransferViewModel, 
// nó sẽ viết version "giáo khoa":
// - Validate amount
// - Call API
// - Show success/error
// 
// → Thiếu 80% business logic thực tế
```

```swift
// ❌ SCENARIO: Healthcare app — Medication reminder
// 
// LLM CAN: schedule UNNotification cho reminder
// LLM CANNOT: 
// 
// 1. Một số thuốc phải uống trước ăn 30 phút, 
//    một số sau ăn
//    → Reminder timing phụ thuộc vào meal schedule 
//      CỦA USER CỤ THỂ
//
// 2. Nếu user miss 3 doses liên tiếp → escalate 
//    notification tới caregiver
//    → Business rule từ healthcare provider
//    → Privacy concern: gửi health data cho 
//      người khác cần consent
//
// 3. Certain medications interact → 
//    không được uống cùng lúc
//    → Drug interaction database không phải 
//      thứ LLM có
//
// 4. Dosage adjustment theo cân nặng → 
//    cần tính toán specific cho từng patient
//
// → LLM viết reminder app nhìn đẹp nhưng 
//   thiếu TOÀN BỘ domain knowledge
```

**Tại sao LLM kém ở business logic?** Vì business logic là **unique per project**. Nó không tồn tại trên GitHub hay StackOverflow. Nó nằm trong Confluence docs, Figma specs, Slack conversations, và đầu của PM/designer. LLM chỉ có thể generate business logic "generic" — đủ cho prototype, nhưng thiếu hầu hết rules thực tế.

---

### 4. "Vùng xám" — LLM đúng ~60-70%, cần review cẩn thận

#### a) SwiftUI layout — đúng cơ bản, sai ở edge case

```swift
// LLM viết layout trông OK trên iPhone 15 Pro
// Nhưng:
// - iPad split view? → layout vỡ
// - Dynamic Type Accessibility XXL? → text overlap
// - Landscape mode? → scroll không đúng
// - RTL languages (Arabic)? → mirror sai
// - Safe area trên iPhone SE vs iPhone 15 
//   Pro Max? → khác nhau

// LLM GENERATE:
struct ProductCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("product")
                .resizable()
                .frame(width: 120, height: 120)  
                // ❌ Hard-coded size → vỡ trên small screen
            
            VStack(alignment: .leading) {
                Text(product.name)
                    .font(.system(size: 18, weight: .bold))  
                    // ❌ Fixed font size → ignore Dynamic Type
                
                Text(product.price)
                    .font(.system(size: 24))
                    // ❌ Same issue
            }
        }
        .padding(16)  // ❌ Fixed padding
    }
}

// ✅ SENIOR DEV REVIEW → FIX:
struct ProductCard: View {
    @Environment(\.dynamicTypeSize) var typeSize
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        // Adaptive layout: HStack on regular, 
        // VStack on compact with large text
        let useVertical = typeSize >= .accessibility1
        
        let layout = useVertical 
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        
        layout {
            Image("product")
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: useVertical ? .infinity : 120)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)  // ✅ Semantic font
                
                Text(product.price)
                    .font(.title2)    // ✅ Scales properly
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}
```

#### b) Error handling — đúng pattern, sai granularity

```swift
// LLM GENERATE:
func loadData() async {
    do {
        let data = try await service.fetch()
        self.items = data
    } catch {
        // ❌ Generic error handling
        self.errorMessage = error.localizedDescription
    }
}

// ✅ SENIOR DEV cần granular handling:
func loadData() async {
    do {
        let data = try await service.fetch()
        self.items = data
    } catch is CancellationError {
        // User navigated away — không show error
        return
    } catch APIError.unauthorized {
        // Token issue — trigger re-auth flow
        await authCoordinator.requestReauthentication()
    } catch APIError.networkUnavailable {
        // Show offline banner, load cached data
        self.items = try? await cacheService.loadCachedItems()
        self.showOfflineBanner = true
    } catch APIError.serverError(let code) where code == 503 {
        // Maintenance mode — show specific screen
        self.showMaintenanceScreen = true
    } catch {
        // Actually generic error — 
        // nhưng log để debug, KHÔNG show localizedDescription
        // vì nó có thể leak internal info
        logger.error("Load data failed: \(error)")
        self.errorMessage = "Không thể tải dữ liệu. Vui lòng thử lại."
    }
}

// LLM sẽ KHÔNG BAO GIỜ viết được error handling 
// chi tiết này vì nó phụ thuộc vào:
// - App có offline mode không?
// - Auth flow như thế nào?
// - Error message policy (localized? generic?)
// - Server có maintenance mode không?
// - Analytics cần log gì?
```

---

### 5. Framework đánh giá: Khi nào tin LLM?

Qua thời gian, senior dev hình thành mental model:

```
LLM Reliability Spectrum cho iOS Development

HIGH CONFIDENCE (dùng trực tiếp, review nhẹ)
├── Boilerplate / scaffolding
├── Codable model generation từ JSON
├── Extension utilities (Date, String, UIColor...)
├── Convert callback → async/await
├── Simple Auto Layout / SwiftUI layout
├── Unit test cho pure functions
├── Giải thích API / concept
└── Regex, string manipulation, data transformation

MEDIUM CONFIDENCE (dùng nhưng review kỹ)
├── SwiftUI complex layout (cần test multi-device)
├── Combine pipeline (check retain cycles)
├── Generic error handling (cần thêm business cases)
├── Core Data / SwiftData queries (check performance)
├── Animation code (cần verify visual output)
└── Protocol-oriented design (check abstraction đúng level)

LOW CONFIDENCE (chỉ dùng làm starting point)
├── Complex state management (nhiều rules interact)
├── Concurrency / Actor isolation
├── Performance optimization (cần profiling thực)
├── Security-sensitive code (auth, crypto, keychain)
├── Business logic specific cho project
├── Navigation / deep link complex flows
├── Memory management trong long-lived objects
└── Migration strategies (UIKit → SwiftUI)
```

### 6. Cách phát triển intuition này

Intuition không đến từ đọc bài — nó đến từ thực hành có ý thức:

Giai đoạn 1 (tháng 1-2): Bạn dùng LLM cho mọi thứ, rồi phát hiện bug trong production do AI-generated code. Những bug này "đau" nhất nhưng dạy nhiều nhất — bạn bắt đầu nhớ "à, lần trước LLM cũng sai chỗ này".

Giai đoạn 2 (tháng 3-6): Bạn bắt đầu phân loại — biết task nào delegate được, task nào phải tự viết. Prompt engineering cải thiện: bạn cung cấp constraints rõ hơn, nhận output tốt hơn.

Giai đoạn 3 (tháng 6+): LLM trở thành extension tự nhiên của workflow. Bạn không còn nghĩ "nên dùng LLM không?" mà tự động biết. Giống như senior dev không nghĩ "nên dùng Instruments không?" — họ biết đúng lúc cần dùng.

Đây chính là "significant experience" mà job description yêu cầu — không phải biết dùng tool, mà là biết **dùng đúng lúc, đúng chỗ, và biết khi nào không nên dùng**.
