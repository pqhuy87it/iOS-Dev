# App Routing trong iOS Development

App Routing (hay còn gọi là Navigation/Coordinator pattern) là một khái niệm kiến trúc quan trọng, đặc biệt khi ứng dụng scale lên. Với tư cách senior iOS developer, đây là những gì bạn cần nắm vững:

---

## 1. Vấn đề cốt lõi mà App Routing giải quyết

Trong một ứng dụng nhỏ, việc navigate giữa các màn hình thường được xử lý trực tiếp trong ViewController:

```swift
// ❌ Cách làm phổ biến nhưng KHÔNG tốt khi scale
class ProductListVC: UIViewController {
    func didTapProduct(_ product: Product) {
        let detailVC = ProductDetailVC(product: product)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
```

**Vấn đề phát sinh:**
- ViewController biết quá nhiều về ViewController khác → **tight coupling**
- Không thể reuse `ProductListVC` ở context khác (ví dụ: push vs present vs deeplink)
- Khó viết unit test cho navigation logic
- Deeplink, universal link xử lý rải rác khắp nơi

---

## 2. Coordinator Pattern — Giải pháp kinh điển (UIKit)

Đây là pattern phổ biến nhất để quản lý routing trong UIKit:

```swift
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }
    func start()
}

class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        if AuthService.shared.isLoggedIn {
            showMainFlow()
        } else {
            showAuthFlow()
        }
    }

    private func showAuthFlow() {
        let authCoordinator = AuthCoordinator(nav: navigationController)
        authCoordinator.delegate = self
        childCoordinators.append(authCoordinator)
        authCoordinator.start()
    }

    private func showMainFlow() {
        let tabCoordinator = TabBarCoordinator(nav: navigationController)
        childCoordinators.append(tabCoordinator)
        tabCoordinator.start()
    }
}
```

```swift
class ProductCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    func start() {
        let vc = ProductListVC()
        vc.delegate = self // VC không biết navigate đi đâu
        navigationController.pushViewController(vc, animated: true)
    }
}

extension ProductCoordinator: ProductListVCDelegate {
    func didSelectProduct(_ product: Product) {
        let detailVC = ProductDetailVC(product: product)
        detailVC.delegate = self
        navigationController.pushViewController(detailVC, animated: true)
    }

    func didTapCart() {
        let cartCoordinator = CartCoordinator(nav: navigationController)
        childCoordinators.append(cartCoordinator)
        cartCoordinator.start()
    }
}
```

**Ưu điểm:** ViewController hoàn toàn không biết về navigation → dễ test, dễ reuse.

---

## 3. Router Pattern — Centralized Routing

Một approach khác là tập trung toàn bộ routing logic vào một Router:

```swift
enum AppRoute: Hashable {
    case productList(categoryId: String)
    case productDetail(productId: String)
    case cart
    case checkout
    case profile(userId: String)
    case settings
}

protocol Router {
    func navigate(to route: AppRoute)
    func pop()
    func popToRoot()
    func present(_ route: AppRoute)
    func dismiss()
}

class AppRouter: Router {
    private let navigationController: UINavigationController
    private let factory: ViewControllerFactory

    func navigate(to route: AppRoute) {
        let vc = factory.makeViewController(for: route)
        configure(vc, for: route)
        navigationController.pushViewController(vc, animated: true)
    }
}

// Factory tách biệt việc khởi tạo VC
class ViewControllerFactory {
    private let dependencies: DependencyContainer

    func makeViewController(for route: AppRoute) -> UIViewController {
        switch route {
        case .productList(let categoryId):
            return ProductListVC(
                viewModel: ProductListVM(
                    categoryId: categoryId,
                    service: dependencies.productService
                )
            )
        case .productDetail(let productId):
            return ProductDetailVC(
                viewModel: ProductDetailVM(
                    productId: productId,
                    service: dependencies.productService
                )
            )
        case .cart:
            return CartVC(viewModel: CartVM(service: dependencies.cartService))
        default:
            fatalError("Route not implemented")
        }
    }
}
```

---

## 4. SwiftUI — NavigationStack & NavigationPath (iOS 16+)

SwiftUI có built-in routing mechanism mạnh mẽ hơn nhiều:

```swift
// Định nghĩa routes
enum AppRoute: Hashable {
    case productDetail(Product)
    case cart
    case profile(User)
    case settings
}

// Router class quản lý state
@Observable
class NavigationRouter {
    var path = NavigationPath()
    var sheet: AppRoute?
    var fullScreenCover: AppRoute?

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func present(_ route: AppRoute, fullScreen: Bool = false) {
        if fullScreen {
            fullScreenCover = route
        } else {
            sheet = route
        }
    }
}

// Root View
struct ContentView: View {
    @State private var router = NavigationRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            ProductListView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .productDetail(let product):
                        ProductDetailView(product: product)
                    case .cart:
                        CartView()
                    case .profile(let user):
                        ProfileView(user: user)
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .environment(router)
        .sheet(item: $router.sheet) { route in
            sheetContent(for: route)
        }
    }
}

// Sử dụng trong child view — không cần biết chi tiết navigation
struct ProductCardView: View {
    @Environment(NavigationRouter.self) private var router
    let product: Product

    var body: some View {
        Button {
            router.push(.productDetail(product))
        } label: {
            // UI here
        }
    }
}
```

---

## 5. Deep Linking — Thử thách thực sự của Routing

Đây là nơi routing architecture thể hiện giá trị rõ nhất:

```swift
class DeepLinkHandler {
    private let router: Router

    // Universal Links: https://myapp.com/product/123
    // Custom Scheme:   myapp://product/123
    // Push Notification payload

    func handle(url: URL) -> Bool {
        guard let route = parse(url) else { return false }
        router.popToRoot()
        
        // Có thể cần navigate qua nhiều level
        switch route {
        case .productDetail(let id):
            router.navigate(to: .productList(categoryId: "all"))
            router.navigate(to: .productDetail(productId: id))
            
        case .orderDetail(let orderId):
            router.navigate(to: .profile(userId: "me"))
            router.navigate(to: .orderHistory)
            router.navigate(to: .orderDetail(orderId: orderId))
            
        default:
            router.navigate(to: route)
        }
        return true
    }

    private func parse(_ url: URL) -> AppRoute? {
        let components = url.pathComponents.filter { $0 != "/" }
        switch components.first {
        case "product":
            guard let id = components[safe: 1] else { return nil }
            return .productDetail(productId: id)
        case "cart":
            return .cart
        default:
            return nil
        }
    }
}
```

---

## 6. Những điểm Senior Developer cần quan tâm

| Khía cạnh | Chi tiết |
|---|---|
| **Memory management** | Child coordinator phải được remove khi flow kết thúc, tránh retain cycle |
| **State restoration** | Khôi phục navigation stack khi app bị kill (NSUserActivity, Scene State) |
| **Tab-based routing** | Mỗi tab có navigation stack riêng, cần quản lý coordinator tree phù hợp |
| **A/B testing** | Router là nơi lý tưởng để redirect user sang flow khác nhau |
| **Analytics** | Centralized routing = centralized screen tracking |
| **Testability** | Mock Router trong unit test để verify navigation logic |

```swift
// Ví dụ: Unit test navigation
class ProductCoordinatorTests: XCTestCase {
    func test_selectProduct_navigatesToDetail() {
        let mockRouter = MockRouter()
        let sut = ProductCoordinator(router: mockRouter)
        
        sut.didSelectProduct(Product.stub(id: "123"))
        
        XCTAssertEqual(
            mockRouter.lastRoute,
            .productDetail(productId: "123")
        )
    }
}
```

---

## Tóm lại

Với senior iOS developer, App Routing không chỉ là "push/present ViewController". Nó là việc thiết kế một **hệ thống navigation có kiến trúc rõ ràng**, nơi mà navigation logic được tách biệt khỏi UI, hỗ trợ deep linking, dễ test, và có khả năng scale khi ứng dụng phức tạp hơn. Lựa chọn giữa Coordinator, Router, hay NavigationStack phụ thuộc vào tech stack (UIKit vs SwiftUI) và quy mô dự án.

`navigationController` là property được khai báo trong `Coordinator` protocol và implement trong `ProductCoordinator`:

```swift
protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set } // ← đây
    func start()
}

class ProductCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController // ← conform protocol

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    func start() {
        let vc = ProductListVC()
        vc.delegate = self
        navigationController.pushViewController(vc, animated: true)
    }
}
```

Còn giá trị thực tế được **truyền từ parent coordinator** xuống:

```swift
// Trong AppCoordinator hoặc TabBarCoordinator
func showProductFlow() {
    let nav = UINavigationController() // tạo hoặc dùng nav có sẵn
    let productCoordinator = ProductCoordinator(navigationController: nav)
    childCoordinators.append(productCoordinator)
    productCoordinator.start()
}
```

Tóm lại, tất cả coordinator trong cùng một flow **chia sẻ chung một `UINavigationController`** — được truyền từ trên xuống qua `init`. Nhờ vậy khi `ProductCoordinator` gọi `navigationController.pushViewController(...)`, nó push lên đúng navigation stack mà user đang thấy.
