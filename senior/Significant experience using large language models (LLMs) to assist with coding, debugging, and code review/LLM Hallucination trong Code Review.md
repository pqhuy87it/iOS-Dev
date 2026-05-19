## LLM Hallucination trong Code Review iOS — Chi tiết cho Senior Developer

### 1. "Hallucinate" trong context code review nghĩa là gì?

Khác với hallucination thông thường (LLM bịa ra thông tin), trong code review có 2 dạng nguy hiểm:

**False Positive** — LLM flag code đúng là sai. Bạn tốn thời gian "fix" thứ không cần fix, hoặc tệ hơn, refactor thành code xấu hơn.

**False Negative** — LLM bỏ qua bug thực sự, thậm chí khen code "looks good". Bạn tin tưởng merge, bug lên production.

Cả hai đều nguy hiểm, nhưng theo cách khác nhau. Senior dev cần nhận diện được cả hai.

---

### 2. FALSE POSITIVE: LLM flag code đúng là sai

#### a) LLM không hiểu UIKit lifecycle đặc thù

```swift
// CODE CỦA BẠN:
final class ProfileViewController: UIViewController {
    
    private let viewModel: ProfileViewModel
    
    // Custom initializer, bỏ qua coder
    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        // Custom root view — không gọi super.loadView()
        view = ProfileView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }
    
    private func setupBindings() {
        // observe viewModel...
    }
}
```

```
❌ LLM REVIEW (SAI):

"Several issues found:

1. CRITICAL: `loadView()` does not call `super.loadView()`. 
   This will cause the view hierarchy to be improperly 
   initialized. Add `super.loadView()` at the beginning 
   of the method.

2. WARNING: `init(coder:)` calls `fatalError()`. This 
   will crash if the view controller is loaded from a 
   storyboard or XIB. Consider providing a proper 
   implementation.

3. WARNING: `viewModel` is a `let` constant initialized 
   in `init`. Consider using dependency injection via 
   a protocol for better testability."
```

**Tại sao LLM sai cả 3 điểm?**

```swift
// ĐIỂM 1: loadView() KHÔNG ĐƯỢC gọi super
// Apple Documentation rõ ràng:
// "Your custom implementation of this method should not 
//  call super."
// 
// Lý do: super.loadView() tìm XIB/Storyboard file. 
// Nếu không tìm thấy, nó tạo plain UIView.
// Khi bạn gán self.view = CustomView(), gọi super 
// trước sẽ tạo thừa một UIView rồi bị thay thế ngay.
// Gọi super SAU sẽ OVERWRITE custom view.
//
// → LLM áp dụng "luôn gọi super" 
//   như một rule chung — SAI cho loadView()

// ĐIỂM 2: fatalError trong init(coder:) là BEST PRACTICE
// Khi view controller KHÔNG BAO GIỜ dùng storyboard,
// @available(*, unavailable) + fatalError là pattern 
// chuẩn được Apple engineers recommend tại WWDC.
// Nó prevent việc vô tình dùng từ storyboard.
//
// → LLM flag vì nghĩ mọi VC đều cần support 
//   cả programmatic lẫn storyboard. Thực tế, 
//   nhiều project 100% programmatic.

// ĐIỂM 3: viewModel đã là dependency injection
// Inject qua initializer (constructor injection) 
// là HÌNH THỨC DI MẠNH NHẤT — tốt hơn property 
// injection hay method injection.
// Protocol abstraction thêm overhead không cần thiết 
// nếu không có nhu cầu swap implementation.
//
// → LLM suggest "inject via protocol" vì nó đọc 
//   quá nhiều tutorial nói về protocol abstraction.
//   Thực tế, concrete type injection + constructor 
//   là đủ cho hầu hết cases.
```

#### b) LLM không hiểu intentional patterns trên iOS

```swift
// PATTERN 1: Intentional force unwrap
// CODE CỦA BẠN:
final class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let apiKey = Bundle.main.infoDictionary!["API_KEY"] as! String
        // ↑ Force unwrap intentional
        
        ConfigurationManager.shared.configure(apiKey: apiKey)
        return true
    }
}

// ❌ LLM REVIEW: "CRITICAL: Force unwrap on 
//    Bundle.main.infoDictionary. Use guard let or 
//    if let to safely unwrap."
//
// ✅ THỰC TẾ: Đây là intentional crash.
// Nếu Info.plist thiếu API_KEY → app KHÔNG NÊN chạy.
// Crash lúc launch tốt hơn crash random lúc runtime.
// Đây là "fail fast" principle — phát hiện 
// configuration error ngay lập tức.
//
// Senior dev biết: force unwrap cho configuration 
// values từ Info.plist là ACCEPTABLE vì:
// - Giá trị này được set lúc build time
// - Nếu thiếu = build configuration sai = cần fix ngay
// - Optional handling ở đây chỉ che giấu lỗi
```

```swift
// PATTERN 2: Singleton — LLM luôn flag
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private init() {}
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected: Bool {
        monitor.currentPath.status == .satisfied
    }
    
    func startMonitoring() {
        monitor.start(queue: queue)
    }
}

// ❌ LLM REVIEW: "Singleton pattern detected. This 
//    creates tight coupling and makes testing difficult. 
//    Consider using dependency injection instead."
//
// ✅ THỰC TẾ: NWPathMonitor singleton là Apple's own 
//    recommended pattern. Bạn chỉ cần MỘT instance 
//    monitor network trên toàn app. Tạo nhiều instance 
//    NWPathMonitor thực sự gây vấn đề (multiple 
//    callbacks, resource waste).
//
// LLM đọc quá nhiều bài "Singleton is anti-pattern" 
// mà quên rằng có legitimate use cases:
// - System resource wrappers (NWPathMonitor, 
//   CLLocationManager dùng chung)
// - Configuration managers
// - Analytics trackers
// - Logging systems
```

```swift
// PATTERN 3: Empty catch — intentional
func preloadCache() {
    Task {
        do {
            let data = try await cacheService.warmUp()
            await MainActor.run { self.cachedData = data }
        } catch {
            // Intentionally empty: cache preload failure 
            // is non-critical. App works fine without cache.
            // Error is already logged in cacheService.warmUp()
        }
    }
}

// ❌ LLM REVIEW: "Empty catch block. Errors should 
//    always be handled or at minimum logged."
//
// ✅ THỰC TẾ: Đôi khi empty catch là ĐÚNG.
// Cache preload là best-effort operation.
// Error đã logged ở layer dưới.
// Thêm handling ở đây = duplicate logging 
// + unnecessary complexity.
//
// Senior dev phân biệt:
// - Empty catch cho CRITICAL operation → ❌ bug
// - Empty catch cho OPTIONAL operation với 
//   comment giải thích → ✅ acceptable
```

#### c) LLM bị outdated — flag new API là sai

```swift
// iOS 17+ code
@Observable
final class CounterViewModel {
    var count = 0
    
    func increment() { count += 1 }
}

struct CounterView: View {
    @State private var viewModel = CounterViewModel()
    
    var body: some View {
        VStack {
            Text("\(viewModel.count)")
            Button("Increment") { viewModel.increment() }
        }
    }
}

// ❌ LLM REVIEW (trained trên data cũ):
// "Issues found:
// 1. CounterViewModel should conform to ObservableObject
// 2. Use @Published for count property
// 3. Use @StateObject instead of @State for 
//    reference type"
//
// ✅ THỰC TẾ: @Observable (iOS 17+, Observation 
//    framework) thay thế ObservableObject.
// - Không cần @Published
// - Dùng @State (không phải @StateObject) 
//   cho @Observable class
// - Performance tốt hơn: chỉ re-render 
//   khi property THỰC SỰ ĐƯỢC ĐỌC thay đổi
//
// LLM trained trên millions of pre-iOS17 code samples
// → bias cực mạnh về ObservableObject pattern
```

```swift
// Swift 5.9+ code
struct ContentView: View {
    var body: some View {
        List {
            ForEach(sections) { section in
                // If/else directly in ViewBuilder — 
                // không cần Group {} wrapper
                if section.items.isEmpty {
                    ContentUnavailableView(
                        "No items",
                        systemImage: "tray"
                    )
                } else {
                    ForEach(section.items) { item in
                        ItemRow(item: item)
                    }
                }
            }
        }
    }
}

// ❌ LLM có thể flag: "Conditional logic in 
//    ViewBuilder should be wrapped in Group {}"
//
// ✅ Swift 5.9: ViewBuilder đã support 
//    if/else trực tiếp không cần Group.
//    Thực tế Group {} ở đây là unnecessary wrapper.
```

```swift
// iOS 16+ Navigation
struct AppNavigation: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .profile(let id):
                        ProfileView(userId: id)
                    case .settings:
                        SettingsView()
                    }
                }
        }
    }
}

// ❌ LLM REVIEW: "Consider using NavigationView 
//    instead for broader compatibility."
//
// ✅ NavigationView đã DEPRECATED từ iOS 16.
//    NavigationStack là replacement.
//    LLM bias vì training data phần lớn 
//    là pre-iOS16 code.
```

#### d) LLM áp dụng rules ngôn ngữ khác vào Swift

```swift
// CODE CỦA BẠN:
struct UserService {
    private let client: HTTPClient
    private let cache: CacheService
    
    func fetchUser(id: String) async throws -> User {
        if let cached = try? await cache.get(key: "user_\(id)", 
                                              as: User.self) {
            return cached
        }
        let user = try await client.get("/users/\(id)", 
                                         response: User.self)
        try? await cache.set(key: "user_\(id)", value: user)
        return user
    }
}

// ❌ LLM REVIEW: "UserService should be a class 
//    conforming to a protocol (e.g., UserServiceProtocol) 
//    for proper dependency injection and mocking in tests."
//
// ✅ THỰC TẾ: Struct là PREFERRED default trong Swift.
// - Value semantics = no unexpected shared mutation
// - Protocols cho DI: đúng nếu bạn cần mock, 
//   NHƯNG bạn có thể inject closure hoặc dùng 
//   struct trực tiếp trong tests
// - "Protocol for everything" là Java/C# thinking, 
//   không phải Swift idiom
//
// Swift community (bao gồm Point-Free, Apple engineers) 
// increasingly prefer:
// - Struct + closure injection
// - Hoặc protocol CHỈ KHI có nhiều implementations thực sự
//
// LLM bị bias từ Java/Kotlin patterns
// áp dụng vào Swift
```

---

### 3. FALSE NEGATIVE: LLM bỏ qua bug thực sự

Đây là dạng nguy hiểm hơn vì tạo **false sense of security**.

#### a) Memory leak ẩn — LLM khen "looks good"

```swift
// CODE CÓ BUG:
final class ChatViewController: UIViewController {
    
    private var messages: [Message] = []
    private let chatService: ChatService
    private var listener: AnyCancellable?
    
    init(chatService: ChatService) {
        self.chatService = chatService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startListening()
    }
    
    private func startListening() {
        listener = chatService.messageStream()
            .sink { [weak self] message in
                self?.messages.append(message)
                self?.tableView.reloadData()
            }
    }
    
    private func sendMessage(_ text: String) {
        let message = Message(text: text, sender: .me)
        messages.append(message)
        tableView.reloadData()
        
        // ❌ BUG ẨN: Timer retain cycle
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            // Nếu message chưa delivered sau 5s → show retry
            if !message.isDelivered {
                self.showRetryButton(for: message)
                // ↑ STRONG capture self!
                // Timer → closure → self → Timer (qua RunLoop)
                // ViewController KHÔNG dealloc khi pop
            }
        }
        
        chatService.send(message)
    }
    
    private func showRetryButton(for message: Message) {
        // update UI...
    }
}

// ❌ LLM REVIEW: "Code looks well-structured. 
//    Good use of [weak self] in the sink subscriber.
//    The message sending logic is clean. 
//    No major issues found."
//
// ✅ BUG THỰC SỰ: Timer.scheduledTimer closure 
//    capture self STRONGLY
// - User mở chat → send message → pop VC ngay
// - Timer vẫn giữ strong ref → VC không dealloc
// - 5 giây sau, showRetryButton() chạy 
//   trên VC đã pop → potential crash hoặc 
//   UI update trên invisible VC
// - Mỗi message gửi = thêm 1 potential leak
// - Nếu user gửi 50 messages rồi pop 
//   → 50 strong refs giữ VC
//
// LLM thấy [weak self] ở sink → nghĩ 
// developer "biết xử lý retain cycle"
// → KHÔNG scan tiếp phần dưới
//
// ✅ FIX:
Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
    guard let self else { return }
    if !message.isDelivered {
        self.showRetryButton(for: message)
    }
}
// Hoặc tốt hơn: dùng Task { try await Task.sleep } 
// để automatic cancellation khi VC dealloc
```

#### b) Thread safety — LLM không "chạy" code trong đầu

```swift
// CODE CÓ BUG:
final class ImageDownloadManager {
    static let shared = ImageDownloadManager()
    
    private var activeDownloads: [URL: URLSessionDataTask] = [:]
    private var completionHandlers: [URL: [(UIImage?) -> Void]] = [:]
    
    func downloadImage(
        url: URL, 
        completion: @escaping (UIImage?) -> Void
    ) {
        // Check if already downloading
        if activeDownloads[url] != nil {
            // Coalesce: thêm completion vào list đợi
            completionHandlers[url, default: []].append(completion)
            return
        }
        
        completionHandlers[url] = [completion]
        
        let task = URLSession.shared.dataTask(with: url) { 
            [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init)
            
            // Notify all waiting completions
            self?.completionHandlers[url]?.forEach { handler in
                DispatchQueue.main.async { handler(image) }
            }
            self?.completionHandlers[url] = nil
            self?.activeDownloads[url] = nil
        }
        
        activeDownloads[url] = task
        task.resume()
    }
    
    func cancelDownload(url: URL) {
        activeDownloads[url]?.cancel()
        activeDownloads[url] = nil
        completionHandlers[url] = nil
    }
}

// ❌ LLM REVIEW: "Good implementation of download 
//    coalescing pattern. Properly uses [weak self] 
//    and dispatches completion to main queue. 
//    Consider adding cache layer."
//
// ✅ BUG THỰC SỰ: DATA RACE trên DICTIONARY
// activeDownloads và completionHandlers là var Dictionary
// - downloadImage() gọi từ main thread (cell configure)
// - URLSession completion chạy trên background thread
// - cancelDownload() có thể gọi từ bất kỳ thread nào
//
// Scenario crash:
// 1. Thread A (main): downloadImage() → 
//    đọc activeDownloads[url]
// 2. Thread B (URLSession): completion → 
//    ghi activeDownloads[url] = nil
// 3. → SIMULTANEOUS READ/WRITE → EXC_BAD_ACCESS
//
// Đây là bug mà Thread Sanitizer sẽ catch, 
// nhưng LLM KHÔNG DETECT vì nó không simulate 
// concurrent execution.
//
// ✅ FIX: Dùng serial queue hoặc actor
actor ImageDownloadManager {
    static let shared = ImageDownloadManager()
    
    private var activeDownloads: [URL: Task<UIImage?, Never>] = [:]
    
    func downloadImage(url: URL) async -> UIImage? {
        if let existing = activeDownloads[url] {
            return await existing.value
        }
        
        let task = Task<UIImage?, Never> {
            let data = try? await URLSession.shared.data(from: url).0
            return data.flatMap(UIImage.init)
        }
        
        activeDownloads[url] = task
        let image = await task.value
        activeDownloads[url] = nil
        return image
    }
}
```

#### c) Logic bug ẩn trong business flow

```swift
// CODE CÓ BUG:
final class SubscriptionManager {
    
    enum SubscriptionTier: Comparable {
        case free, basic, premium, enterprise
    }
    
    func canAccessFeature(
        _ feature: Feature, 
        userTier: SubscriptionTier
    ) -> Bool {
        return userTier >= feature.requiredTier
    }
    
    func handlePurchase(
        product: StoreProduct, 
        currentTier: SubscriptionTier
    ) async throws -> PurchaseResult {
        
        // Verify with App Store
        let transaction = try await StoreKit2Manager
            .shared.purchase(product)
        
        // Update user tier
        let newTier = product.associatedTier
        try await apiService.updateSubscription(
            tier: newTier
        )
        
        // Grant access immediately
        UserDefaults.standard.set(
            newTier.rawValue, 
            forKey: "current_tier"
        )
        
        return PurchaseResult(
            success: true, 
            newTier: newTier
        )
    }
    
    func handleRestore() async throws -> [SubscriptionTier] {
        let transactions = try await StoreKit2Manager
            .shared.restorePurchases()
        
        let tiers = transactions.compactMap { 
            $0.productID.associatedTier 
        }
        
        // Restore highest tier
        if let highest = tiers.max() {
            try await apiService.updateSubscription(
                tier: highest
            )
            UserDefaults.standard.set(
                highest.rawValue, 
                forKey: "current_tier"
            )
        }
        
        return tiers
    }
}

// ❌ LLM REVIEW: "Clean subscription management. 
//    Good use of StoreKit 2. Consider adding error 
//    handling for network failures during 
//    updateSubscription."
//
// ✅ BUGS THỰC SỰ (cần business knowledge):
```

```swift
// BUG 1: DOWNGRADE KHÔNG ĐƯỢC HANDLE
// User đang Premium, mua Basic (downgrade) 
// → code ghi đè newTier = basic ngay lập tức
// → User MẤT premium access NGAY, 
//   dù premium subscription còn valid đến cuối kỳ
// 
// Apple's rule: downgrade chỉ có hiệu lực 
// ở NEXT billing cycle
// → Cần check: newTier < currentTier 
//   → schedule downgrade, KHÔNG apply ngay

// BUG 2: RACE CONDITION giữa purchase và server update
// 1. StoreKit purchase thành công → tiền đã trừ
// 2. apiService.updateSubscription() FAIL (network)
// 3. UserDefaults KHÔNG được update
// 4. → User đã trả tiền nhưng không có access
// 5. → App restart: đọc UserDefaults = free tier
// 6. → User complaint
//
// FIX: Cần receipt validation server-side, 
// KHÔNG rely on client state.
// UserDefaults là cache, source of truth phải là 
// server + StoreKit Transaction.currentEntitlements

// BUG 3: UserDefaults cho subscription tier
// UserDefaults KHÔNG ENCRYPTED → jailbreak users 
// có thể edit plist file → set tier = enterprise
// → Bypass paywall hoàn toàn
//
// FIX: Dùng Keychain hoặc server-side validation

// BUG 4: handleRestore() logic sai
// Restore chỉ restore ACTIVE subscriptions
// Nhưng code lấy max() của TẤT CẢ transactions 
// bao gồm cả EXPIRED ones
// → User từng mua enterprise 2 năm trước, 
//   đã cancel → restore → được enterprise lại
//
// FIX: Filter transactions by status:
// transactions.filter { 
//     $0.revocationDate == nil && 
//     $0.expirationDate ?? .distantFuture > Date() 
// }

// BUG 5: Family Sharing không handle
// User A mua premium → share với User B
// User B restore → nhận premium
// User A cancel → User B vẫn thấy premium 
// trong UserDefaults
// → Cần listen Transaction.updates 
//   cho real-time revocation

// → LLM BỎ QUA TẤT CẢ 5 BUGS NÀY vì:
// 1. Code syntax hoàn toàn đúng
// 2. Logic flow nhìn hợp lý nếu không biết 
//    StoreKit business rules
// 3. Apple's subscription lifecycle phức tạp 
//    hơn code thể hiện rất nhiều
// 4. Security concern (UserDefaults) 
//    là domain-specific knowledge
```

#### d) Performance bug — LLM không profile

```swift
// CODE CÓ BUG:
struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.posts) { post in
                    PostCard(post: post)
                        .onAppear {
                            if post.id == viewModel.posts.last?.id {
                                Task { await viewModel.loadMore() }
                            }
                        }
                }
            }
            .padding()
        }
        .task { await viewModel.loadInitial() }
    }
}

struct PostCard: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author header
            HStack {
                AsyncImage(url: post.author.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                Text(post.author.name)
                    .font(.headline)
            }
            
            // Post content
            Text(post.content)
                .font(.body)
            
            // Post image
            if let imageURL = post.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Rectangle()
                        .fill(.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                }
            }
            
            // Interaction buttons
            HStack(spacing: 24) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.right")
                Label("\(post.shareCount)", systemImage: "square.and.arrow.up")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            
            // Timestamp
            Text(post.createdAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 2)
    }
}

// ❌ LLM REVIEW: "Clean SwiftUI feed implementation. 
//    Good use of LazyVStack for performance. 
//    Pagination logic with onAppear is correct. 
//    Consider adding pull-to-refresh."
```

```swift
// ✅ PERFORMANCE BUGS mà LLM hoàn toàn bỏ qua:

// BUG 1: AsyncImage KHÔNG CACHE
// Mỗi lần PostCard re-render (scroll xuống rồi lên)
// → Avatar 40x40 fetch lại từ network
// → Post image fetch lại từ network
// → Feed 100 posts = hàng trăm redundant requests
// → Scroll giật, data usage tăng vọt
//
// Instruments → Network profiler sẽ thấy ngay
// LLM không thấy vì syntax đúng 100%

// BUG 2: Date formatting MỖI RENDER
// post.createdAt.formatted(.relative(...)) 
// tạo DateFormatter MỚI mỗi lần body evaluate
// → 100 visible cells × 60fps scroll = 6000 
//   formatter allocations/giây
// → Micro-stutter khi scroll nhanh
//
// FIX: Cache formatted string hoặc 
// dùng pre-computed relative time string

// BUG 3: Shadow performance
// .shadow(radius: 2) trên MỖI cell
// → Offscreen rendering cho mỗi cell
// → GPU overhead đáng kể trong long list
// → Core Animation Instruments: 
//   yellow highlight trên mọi cell
//
// FIX: .shadow tĩnh hoặc dùng 
// .compositingGroup() trước .shadow
// Hoặc fake shadow bằng gradient overlay

// BUG 4: PostCard không Equatable
// SwiftUI không biết khi nào SKIP re-render
// → Scroll trigger body re-evaluation 
//   cho MỌI visible cell
// → Kết hợp với Bug 1,2,3 = scroll performance 
//   tệ trên older devices

// BUG 5: Pagination trigger sai
// post.id == viewModel.posts.last?.id
// → Chỉ trigger khi cell CUỐI CÙNG appear
// → User phải scroll đến tận cuối rồi ĐỢI load
// → UX: nên trigger trước ~5 cells 
//   để prefetch seamlessly:
.onAppear {
    let threshold = max(viewModel.posts.count - 5, 0)
    if let index = viewModel.posts.firstIndex(where: { 
        $0.id == post.id 
    }), index >= threshold {
        Task { await viewModel.loadMore() }
    }
}
```

#### e) Security bug — LLM xem như code bình thường

```swift
// CODE CÓ BUG:
final class DeepLinkHandler {
    
    func handle(url: URL) -> Bool {
        guard let components = URLComponents(url: url, 
              resolvingAgainstBaseURL: false),
              let host = components.host else {
            return false
        }
        
        switch host {
        case "profile":
            let userId = components.queryItems?
                .first(where: { $0.name == "id" })?.value
            navigateToProfile(userId: userId ?? "")
            
        case "payment":
            let amount = components.queryItems?
                .first(where: { $0.name == "amount" })?.value
            let recipient = components.queryItems?
                .first(where: { $0.name == "to" })?.value
            initiatePayment(
                amount: amount ?? "0", 
                recipient: recipient ?? ""
            )
            
        case "webview":
            let urlString = components.queryItems?
                .first(where: { $0.name == "url" })?.value
            if let urlString, let webURL = URL(string: urlString) {
                openWebView(url: webURL)
            }
            
        default:
            return false
        }
        return true
    }
    
    private func navigateToProfile(userId: String) { /* ... */ }
    private func initiatePayment(amount: String, recipient: String) { /* ... */ }
    private func openWebView(url: URL) { /* ... */ }
}

// ❌ LLM REVIEW: "Clean deep link routing. 
//    Consider using an enum for route types 
//    for better type safety."
//
// ✅ SECURITY BUGS:

// BUG 1: PAYMENT VIA DEEP LINK — NO AUTH CHECK
// Malicious app/website gửi deep link:
// myapp://payment?amount=1000000&to=attacker_account
// → App THỰC HIỆN THANH TOÁN không hỏi user
// → Không verify auth state
// → Không require biometric/PIN confirmation
// → Đây là vulnerability nghiêm trọng

// BUG 2: OPEN REDIRECT via webview
// myapp://webview?url=https://phishing-site.com
// → App mở WKWebView tới phishing site
// → User nghĩ đang trong app → nhập credentials
// → Attacker steal credentials
//
// FIX: Whitelist allowed domains cho webview

// BUG 3: userId KHÔNG SANITIZED
// myapp://profile?id='; DROP TABLE users; --
// → Nếu userId được pass thẳng vào API/database 
//   → SQL injection
// → Nếu render trong WebView → XSS

// BUG 4: KHÔNG VALIDATE deep link source
// iOS cho phép BẤT KỲ app nào gửi deep link
// → Không có cách verify "ai gửi link này"
// → Tất cả deep link phải treated as UNTRUSTED input
// → Payment deep link KHÔNG BAO GIỜ nên auto-execute
```

---

### 4. Tại sao LLM hallucinate trong code review?

```
Root Causes:

1. PATTERN MATCHING ≠ UNDERSTANDING
   LLM "nhìn" code giống đọc text — matching patterns
   Nó thấy: [weak self] → "developer handles retain cycles" ✓
   Nó KHÔNG thấy: Timer closure ở dòng 47 thiếu [weak self]
   → Vì nó không "trace" reference graph

2. TRAINING DATA BIAS
   90% code trên GitHub có:
   - ObservableObject (không phải @Observable)
   - NavigationView (không phải NavigationStack)  
   - "Singleton is bad" (không phải "Singleton is sometimes OK")
   → LLM reflect majority opinion, 
     không phải correct-for-context opinion

3. SINGLE-FILE ANALYSIS
   LLM review file bạn paste.
   Nó KHÔNG biết:
   - File này chạy trên thread nào
   - Ai gọi function này, với data gì
   - Architecture conventions của project
   - Business rules từ Confluence/Figma
   → Miss bugs cần CROSS-FILE understanding

4. SYNTAX vs SEMANTICS
   LLM giỏi: "syntax này đúng không?"
   LLM kém: "logic này làm điều developer MUỐN không?"
   → Security bugs, business logic bugs = semantic bugs
   → LLM chỉ thấy code chạy, không thấy code 
     KHÔNG NÊN chạy trong context này

5. NO RUNTIME SIMULATION
   LLM không:
   - Chạy code trong đầu với multiple threads
   - Simulate user interaction sequences
   - Profile memory/CPU usage
   - Test trên different devices/OS versions
   → Performance, concurrency, device-specific bugs = invisible
```

---

### 5. Senior Dev Playbook: Làm gì với thông tin này?

**Khi dùng LLM review code:**

```
DO:
✅ Dùng LLM scan boilerplate issues: 
   naming convention, formatting, unused imports
✅ Dùng LLM verify API usage cơ bản: 
   "tôi dùng API này đúng chưa?"
✅ Dùng LLM generate review checklist 
   cho specific file type
✅ Cross-check: nếu LLM flag something, 
   verify trước khi fix

DON'T:
❌ Tin LLM review nói "no issues found" 
   = code an toàn
❌ Fix mọi thứ LLM flag 
   mà không verify từ Apple docs
❌ Dùng LLM review thay thế cho:
   - Thread Sanitizer (concurrency bugs)
   - Instruments (performance bugs)  
   - Security audit (vulnerability)
   - Manual code review (business logic)
❌ Assume LLM hiểu iOS version target 
   của project bạn
```

**Mental model chính xác nhất:** LLM review giống một **junior developer rất chăm chỉ đọc code nhưng chưa từng ship production app**. Nó bắt được typo, naming issues, missing nil checks — những thứ surface-level. Nhưng nó không có kinh nghiệm debug 3 giờ sáng khi production crash, không biết cảm giác khi user bị charge duplicate, không hiểu tại sao empty catch đôi khi là quyết định có chủ đích. Kinh nghiệm production đó chính là thứ biến developer thành **senior** — và LLM chưa có nó.
