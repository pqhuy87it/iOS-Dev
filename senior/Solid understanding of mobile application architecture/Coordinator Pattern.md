# Coordinator Pattern — Tách Navigation Logic ra khỏi ViewController

## 1. Vấn đề: Tại sao cần tách Navigation?

### Code thông thường (không có Coordinator):

```swift
// LoginViewController.swift
class LoginViewController: UIViewController {
    
    func loginDidSucceed(user: User) {
        // ❌ LoginVC phải "biết" HomeViewController
        let homeVC = HomeViewController()
        homeVC.user = user
        navigationController?.pushViewController(homeVC, animated: true)
    }
    
    @objc func forgotPasswordTapped() {
        // ❌ LoginVC phải "biết" ForgotPasswordViewController
        let forgotVC = ForgotPasswordViewController()
        forgotVC.email = emailTextField.text
        let nav = UINavigationController(rootViewController: forgotVC)
        present(nav, animated: true)
    }
    
    @objc func signUpTapped() {
        // ❌ LoginVC phải "biết" SignUpViewController
        let signUpVC = SignUpViewController()
        signUpVC.delegate = self
        navigationController?.pushViewController(signUpVC, animated: true)
    }
}
```

### Vấn đề phát sinh:

**Coupling chặt giữa các ViewController** — `LoginViewController` phải `import` và biết cách khởi tạo `HomeViewController`, `ForgotPasswordViewController`, `SignUpViewController`. Nếu `HomeViewController` đổi cách khởi tạo (thêm parameter), bạn phải sửa ở **tất cả nơi push đến nó**.

**Không thể reuse** — Giả sử bạn muốn dùng lại `LoginViewController` ở một flow khác (ví dụ: re-authenticate trước khi đổi mật khẩu), nhưng sau khi login xong cần quay về Settings thay vì vào Home. Bạn phải sửa code bên trong LoginVC hoặc thêm if/else rối rắm.

**Khó test** — Muốn test logic "sau khi login thành công thì chuyển đến Home" thì phải khởi tạo cả `UINavigationController`, cả `HomeViewController`... rất khó viết unit test.

**Flow logic bị phân tán** — Muốn hiểu toàn bộ flow đăng nhập (Login → Home? Login → Onboarding → Home? Login → Force Update?), bạn phải mở từng ViewController một để đọc, không có nơi nào mô tả flow tổng thể.

---

## 2. Giải pháp: Coordinator Pattern

### Ý tưởng cốt lõi

Tạo một **object riêng biệt (Coordinator)** chuyên chịu trách nhiệm:
- Khởi tạo ViewController
- Quyết định chuyển đến màn hình nào
- Quản lý toàn bộ navigation flow

**ViewController KHÔNG biết** mình sẽ đi đâu tiếp theo. Nó chỉ **thông báo** "tôi đã hoàn thành việc X" và để Coordinator quyết định bước tiếp theo.

```
TRƯỚC (VC biết nhau):
LoginVC ──push──→ HomeVC ──push──→ ProfileVC
   │
   └──present──→ ForgotPasswordVC

SAU (Coordinator quản lý):
                  ┌──────────────────┐
                  │   Coordinator    │  ← Biết tất cả VC, quản lý flow
                  └──────┬───────────┘
                         │ creates & navigates
              ┌──────────┼──────────┐
              ▼          ▼          ▼
          LoginVC     HomeVC    ForgotVC   ← Các VC không biết nhau
```

---

## 3. Triển khai Coordinator Pattern (UIKit)

### 3.1. Protocol cơ bản

```swift
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }
    
    func start()
}
```

`childCoordinators` là mảng giữ **strong reference** đến các coordinator con. Nếu không giữ, coordinator con sẽ bị ARC giải phóng ngay sau khi `start()` chạy xong (vì không ai giữ reference đến nó nữa).

### 3.2. AppCoordinator — Coordinator gốc

```swift
class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    private let window: UIWindow
    
    init(window: UIWindow) {
        self.window = window
        self.navigationController = UINavigationController()
    }
    
    func start() {
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        
        if isUserLoggedIn() {
            showMainFlow()
        } else {
            showAuthFlow()
        }
    }
    
    // ──────── Flow Management ────────
    
    private func showAuthFlow() {
        let authCoordinator = AuthCoordinator(navigationController: navigationController)
        authCoordinator.delegate = self
        childCoordinators.append(authCoordinator)   // Giữ reference
        authCoordinator.start()
    }
    
    private func showMainFlow() {
        let mainCoordinator = MainTabCoordinator(navigationController: navigationController)
        mainCoordinator.delegate = self
        childCoordinators.append(mainCoordinator)
        mainCoordinator.start()
    }
    
    private func isUserLoggedIn() -> Bool {
        return TokenManager.shared.hasValidToken
    }
}

// MARK: - Nhận tín hiệu từ AuthCoordinator
extension AppCoordinator: AuthCoordinatorDelegate {
    func authCoordinatorDidFinishLogin(_ coordinator: AuthCoordinator) {
        // Xóa coordinator con khỏi mảng (giải phóng bộ nhớ)
        childCoordinators.removeAll { $0 === coordinator }
        showMainFlow()
    }
}
```

### 3.3. AuthCoordinator — Coordinator quản lý flow xác thực

```swift
protocol AuthCoordinatorDelegate: AnyObject {
    func authCoordinatorDidFinishLogin(_ coordinator: AuthCoordinator)
}

class AuthCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController
    
    weak var delegate: AuthCoordinatorDelegate?
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        showLogin()
    }
    
    // ──────── Screens ────────
    
    private func showLogin() {
        let loginVC = LoginViewController()
        loginVC.delegate = self          // VC báo kết quả về Coordinator
        navigationController.setViewControllers([loginVC], animated: false)
    }
    
    private func showSignUp() {
        let signUpVC = SignUpViewController()
        signUpVC.delegate = self
        navigationController.pushViewController(signUpVC, animated: true)
    }
    
    private func showForgotPassword(email: String?) {
        let forgotVC = ForgotPasswordViewController(prefilledEmail: email)
        forgotVC.delegate = self
        let nav = UINavigationController(rootViewController: forgotVC)
        navigationController.present(nav, animated: true)
    }
    
    private func showOnboarding(user: User) {
        let onboardingVC = OnboardingViewController(user: user)
        onboardingVC.delegate = self
        navigationController.pushViewController(onboardingVC, animated: true)
    }
}
```

### 3.4. ViewController — Chỉ báo sự kiện, không biết đi đâu

```swift
// ──────── Protocol: VC giao tiếp với Coordinator ────────

protocol LoginViewControllerDelegate: AnyObject {
    func loginVCDidLogin(user: User)
    func loginVCDidTapSignUp()
    func loginVCDidTapForgotPassword(email: String?)
}

// ──────── ViewController "sạch" — không chứa navigation logic ────────

class LoginViewController: UIViewController {
    
    weak var delegate: LoginViewControllerDelegate?
    
    private let viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel = LoginViewModel()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    @objc private func loginButtonTapped() {
        viewModel.login(
            email: emailField.text ?? "",
            password: passwordField.text ?? ""
        ) { [weak self] result in
            switch result {
            case .success(let user):
                // ✅ Chỉ BÁO, không tự navigate
                self?.delegate?.loginVCDidLogin(user: user)
                
            case .failure(let error):
                self?.showError(error)
            }
        }
    }
    
    @objc private func signUpTapped() {
        delegate?.loginVCDidTapSignUp()       // ✅ Chỉ báo
    }
    
    @objc private func forgotPasswordTapped() {
        delegate?.loginVCDidTapForgotPassword(email: emailField.text)  // ✅ Chỉ báo
    }
}
```

**So sánh:**

```swift
// ❌ TRƯỚC: VC tự navigate
func loginDidSucceed(user: User) {
    let homeVC = HomeViewController()     // Phải biết HomeVC
    homeVC.user = user                     // Phải biết cách config HomeVC
    navigationController?.push(homeVC)     // Phải biết navigation logic
}

// ✅ SAU: VC chỉ báo sự kiện
func loginDidSucceed(user: User) {
    delegate?.loginVCDidLogin(user: user)  // Chỉ nói "tôi login xong rồi"
}
```

### 3.5. Coordinator nhận sự kiện và quyết định navigation

```swift
// MARK: - AuthCoordinator xử lý TẤT CẢ navigation decisions

extension AuthCoordinator: LoginViewControllerDelegate {
    
    func loginVCDidLogin(user: User) {
        if user.isFirstLogin {
            showOnboarding(user: user)       // User mới → Onboarding
        } else {
            delegate?.authCoordinatorDidFinishLogin(self)  // User cũ → về Home
        }
    }
    
    func loginVCDidTapSignUp() {
        showSignUp()
    }
    
    func loginVCDidTapForgotPassword(email: String?) {
        showForgotPassword(email: email)
    }
}

extension AuthCoordinator: SignUpViewControllerDelegate {
    
    func signUpVCDidComplete(user: User) {
        showOnboarding(user: user)           // Đăng ký xong → Onboarding
    }
    
    func signUpVCDidTapBack() {
        navigationController.popViewController(animated: true)
    }
}

extension AuthCoordinator: OnboardingViewControllerDelegate {
    
    func onboardingVCDidFinish() {
        delegate?.authCoordinatorDidFinishLogin(self)  // Xong → báo lên AppCoordinator
    }
}
```

**Bây giờ toàn bộ flow Auth được mô tả rõ ràng trong MỘT file:**

```
AuthCoordinator:
  Login ──(first login)──→ Onboarding ──→ Main App
  Login ──(returning user)──→ Main App
  Login ──(sign up)──→ SignUp ──→ Onboarding ──→ Main App
  Login ──(forgot)──→ ForgotPassword
```

---

## 4. Cây Coordinator — Phân cấp quản lý

Với app phức tạp, bạn sẽ có nhiều Coordinator lồng nhau:

```
AppCoordinator
├── AuthCoordinator
│   ├── LoginVC
│   ├── SignUpVC
│   ├── ForgotPasswordVC
│   └── OnboardingVC
│
└── MainTabCoordinator
    ├── HomeCoordinator (Tab 1)
    │   ├── HomeVC
    │   ├── ProductDetailVC
    │   └── ReviewsVC
    │
    ├── SearchCoordinator (Tab 2)
    │   ├── SearchVC
    │   └── SearchResultVC
    │
    ├── CartCoordinator (Tab 3)
    │   ├── CartVC
    │   └── CheckoutCoordinator (sub-flow)
    │       ├── ShippingVC
    │       ├── PaymentVC
    │       └── ConfirmationVC
    │
    └── ProfileCoordinator (Tab 4)
        ├── ProfileVC
        ├── SettingsVC
        └── EditProfileVC
```

Mỗi Coordinator quản lý một **flow logic** hoàn chỉnh. `CartCoordinator` không cần biết `AuthCoordinator` tồn tại. Khi cần giao tiếp cross-flow (ví dụ: từ Cart quay về Login khi token hết hạn), sẽ delegate ngược lên `AppCoordinator`.

---

## 5. Nâng cao: Factory Pattern kết hợp Coordinator

Senior thường kết hợp **Factory** để Coordinator không phải khởi tạo VC trực tiếp:

```swift
// Factory tạo VC với đầy đủ dependencies
protocol ViewControllerFactory {
    func makeLoginVC(delegate: LoginViewControllerDelegate) -> LoginViewController
    func makeHomeVC(user: User) -> HomeViewController
    func makeProductDetailVC(productId: String) -> ProductDetailViewController
}

class DefaultViewControllerFactory: ViewControllerFactory {
    
    private let apiClient: APIClientProtocol
    private let analyticsService: AnalyticsService
    
    init(apiClient: APIClientProtocol, analyticsService: AnalyticsService) {
        self.apiClient = apiClient
        self.analyticsService = analyticsService
    }
    
    func makeLoginVC(delegate: LoginViewControllerDelegate) -> LoginViewController {
        let repository = AuthRepository(apiClient: apiClient)
        let viewModel = LoginViewModel(repository: repository)
        let vc = LoginViewController(viewModel: viewModel)
        vc.delegate = delegate
        return vc
    }
    
    func makeHomeVC(user: User) -> HomeViewController {
        let repository = HomeRepository(apiClient: apiClient)
        let viewModel = HomeViewModel(user: user, repository: repository)
        return HomeViewController(viewModel: viewModel)
    }
    
    func makeProductDetailVC(productId: String) -> ProductDetailViewController {
        let repository = ProductRepository(apiClient: apiClient)
        let viewModel = ProductDetailViewModel(
            productId: productId,
            repository: repository,
            analytics: analyticsService
        )
        return ProductDetailViewController(viewModel: viewModel)
    }
}

// Coordinator dùng Factory — không biết chi tiết khởi tạo
class AuthCoordinator: Coordinator {
    private let factory: ViewControllerFactory
    
    init(navigationController: UINavigationController, factory: ViewControllerFactory) {
        self.factory = factory
        // ...
    }
    
    private func showLogin() {
        let loginVC = factory.makeLoginVC(delegate: self)  // ✅ Gọn, rõ ràng
        navigationController.setViewControllers([loginVC], animated: false)
    }
}
```

**Lợi ích:** Coordinator chỉ quan tâm **"show màn hình nào, khi nào"**, không quan tâm **"tạo màn hình đó như thế nào"** (cần inject gì, dependency gì). Factory lo việc đó.

---

## 6. Deep Linking với Coordinator

Coordinator rất mạnh khi xử lý Deep Link — bạn chỉ cần "ra lệnh" cho đúng coordinator:

```swift
// URL: myapp://product/123

class AppCoordinator: Coordinator {
    
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else { return }
        
        switch host {
        case "product":
            let productId = components.path.replacingOccurrences(of: "/", with: "")
            navigateToProduct(productId)
            
        case "profile":
            navigateToProfile()
            
        case "promo":
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
            navigateToPromo(code: code)
            
        default:
            break
        }
    }
    
    private func navigateToProduct(_ productId: String) {
        // 1. Đảm bảo đang ở MainTab
        if !isShowingMainFlow {
            showMainFlow()
        }
        
        // 2. Chuyển đến tab Home
        guard let mainCoordinator = childCoordinators
            .compactMap({ $0 as? MainTabCoordinator }).first else { return }
        mainCoordinator.selectTab(.home)
        
        // 3. Push ProductDetail
        guard let homeCoordinator = mainCoordinator.childCoordinators
            .compactMap({ $0 as? HomeCoordinator }).first else { return }
        homeCoordinator.showProductDetail(productId: productId)
    }
}
```

Mỗi Coordinator chỉ quản lý navigation trong phạm vi của nó. Deep link handler ở tầng cao nhất sẽ "chuyển lệnh" xuống đúng coordinator con.

---

## 7. Coordinator trong SwiftUI

SwiftUI quản lý navigation khác UIKit (declarative thay vì imperative), nên Coordinator cũng cần thích ứng:

### Cách 1: Router với NavigationStack (phổ biến nhất)

```swift
// Định nghĩa tất cả destination có thể navigate đến
enum AppRoute: Hashable {
    case home
    case productDetail(productId: String)
    case profile(userId: String)
    case settings
    case checkout(cart: Cart)
}

// Router quản lý navigation state
@Observable
class AppRouter {
    var path = NavigationPath()
    var presentedSheet: AppRoute?
    var presentedFullScreen: AppRoute?
    
    // ──────── Push ────────
    func push(_ route: AppRoute) {
        path.append(route)
    }
    
    // ──────── Pop ────────
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    // ──────── Present ────────
    func presentSheet(_ route: AppRoute) {
        presentedSheet = route
    }
    
    func presentFullScreen(_ route: AppRoute) {
        presentedFullScreen = route
    }
    
    func dismiss() {
        presentedSheet = nil
        presentedFullScreen = nil
    }
}
```

```swift
// View sử dụng Router
struct ContentView: View {
    @State private var router = AppRouter()
    
    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
                .sheet(item: $router.presentedSheet) { route in
                    destinationView(for: route)
                }
                .fullScreenCover(item: $router.presentedFullScreen) { route in
                    destinationView(for: route)
                }
        }
        .environment(router)   // Inject router cho toàn bộ cây view
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        case .productDetail(let productId):
            ProductDetailView(productId: productId)
        case .profile(let userId):
            ProfileView(userId: userId)
        case .settings:
            SettingsView()
        case .checkout(let cart):
            CheckoutView(cart: cart)
        }
    }
}
```

```swift
// View con chỉ gọi router, không biết navigate đến đâu
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    
    var body: some View {
        List(products) { product in
            Button(product.name) {
                router.push(.productDetail(productId: product.id))
            }
        }
    }
}
```

### Cách 2: Coordinator Object giữ logic phức tạp

Khi navigation có **logic điều kiện** (kiểm tra auth, feature flag, A/B test...), bạn nên tách logic ra Coordinator riêng thay vì để trong View:

```swift
@Observable
class ShopCoordinator {
    private let router: AppRouter
    private let authService: AuthService
    private let featureFlags: FeatureFlagService
    
    init(router: AppRouter, authService: AuthService, featureFlags: FeatureFlagService) {
        self.router = router
        self.authService = authService
        self.featureFlags = featureFlags
    }
    
    func showProductDetail(productId: String) {
        router.push(.productDetail(productId: productId))
    }
    
    func startCheckout(cart: Cart) {
        // Logic phức tạp: kiểm tra auth, minimum order, feature flag...
        guard authService.isLoggedIn else {
            router.presentSheet(.login(returnAction: .checkout(cart)))
            return
        }
        
        guard cart.totalPrice >= 50_000 else {
            router.presentSheet(.minimumOrderAlert)
            return
        }
        
        if featureFlags.isEnabled(.newCheckoutFlow) {
            router.push(.newCheckout(cart: cart))
        } else {
            router.push(.checkout(cart: cart))
        }
    }
    
    func handlePostPurchase(order: Order) {
        router.popToRoot()
        
        if order.isFirstPurchase {
            router.presentSheet(.referralPromo(orderId: order.id))
        }
    }
}
```

---

## 8. Quản lý Memory — Lỗi phổ biến

### Vấn đề: Child Coordinator bị dealloc sớm

```swift
// ❌ SAI: không giữ reference → coordinator bị giải phóng ngay
func showAuthFlow() {
    let authCoordinator = AuthCoordinator(nav: navigationController)
    authCoordinator.start()
    // authCoordinator bị dealloc ngay sau khi hàm này kết thúc!
}

// ✅ ĐÚNG: giữ trong mảng childCoordinators
func showAuthFlow() {
    let authCoordinator = AuthCoordinator(nav: navigationController)
    childCoordinators.append(authCoordinator)  // Giữ strong reference
    authCoordinator.start()
}
```

### Vấn đề: Quên xóa child coordinator khi flow kết thúc → memory leak

```swift
// ✅ Luôn xóa khi child coordinator hoàn thành
func authCoordinatorDidFinishLogin(_ coordinator: AuthCoordinator) {
    childCoordinators.removeAll { $0 === coordinator }  // Giải phóng
    showMainFlow()
}
```

### Vấn đề: Retain cycle giữa VC và Coordinator

```swift
class LoginViewController: UIViewController {
    weak var delegate: LoginViewControllerDelegate?  // ✅ PHẢI là weak
}
```

Nếu `delegate` không phải `weak`, sẽ tạo retain cycle: Coordinator → (strong) VC → (strong) delegate (Coordinator) → vòng lặp.

---

## 9. Tổng kết so sánh

| Tiêu chí | Không Coordinator | Có Coordinator |
|---|---|---|
| VC coupling | VC A phải biết VC B, C, D | VC không biết nhau |
| Reuse VC | Khó, navigation logic gắn chặt | Dễ, VC chỉ báo sự kiện |
| Đọc hiểu flow | Mở từng VC để trace | Đọc 1 file Coordinator |
| Deep linking | if/else rải rác khắp nơi | Xử lý tập trung tại Coordinator |
| Unit test navigation | Gần như không test được | Test Coordinator dễ dàng |
| Thay đổi flow | Sửa nhiều VC | Sửa 1 Coordinator |

**Một câu tóm lại:** Coordinator là người **"đạo diễn"** — ViewController là **"diễn viên"**. Diễn viên chỉ cần diễn tốt vai của mình (hiển thị UI, nhận input), còn đi đâu, làm gì tiếp theo là việc của đạo diễn quyết định.

Bạn muốn mình đi sâu hơn phần nào không? Ví dụ: cách test Coordinator, xử lý multi-window trên iPad, hay kết hợp Coordinator với TCA?
