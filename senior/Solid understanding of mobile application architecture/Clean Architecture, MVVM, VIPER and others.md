# So sánh chi tiết Clean Architecture với MVVM, VIPER và các Architecture khác trong iOS

Đây là một chủ đề rất quan trọng cho Senior iOS Developer. Mình sẽ phân tích từng architecture, sau đó so sánh trực tiếp trên nhiều tiêu chí.

---

## 1. Tổng quan từng Architecture

### MVC (Model-View-Controller)

Apple's default pattern, đơn giản nhưng dễ dẫn đến "Massive View Controller".

```swift
// Controller chứa cả business logic + presentation logic
class UserListViewController: UIViewController, UITableViewDataSource {
    var users: [User] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Networking logic ngay trong VC
        URLSession.shared.dataTask(with: url) { data, _, _ in
            self.users = try! JSONDecoder().decode([User].self, from: data!)
            DispatchQueue.main.async { self.tableView.reloadData() }
        }.resume()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Presentation logic cũng ở đây
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = users[indexPath.row].name
        return cell
    }
}
```

**Vấn đề:** ViewController vừa quản lý UI, vừa chứa business logic, networking, navigation → không testable, không tái sử dụng.

---

### MVVM (Model-View-ViewModel)

Tách presentation logic ra ViewModel, View chỉ bind data.

```swift
// ========== ViewModel ==========
class UserListViewModel: ObservableObject {
    @Published var users: [UserCellModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userRepository: UserRepositoryProtocol
    
    init(repository: UserRepositoryProtocol) {
        self.userRepository = repository
    }
    
    @MainActor
    func fetchUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let domainUsers = try await userRepository.getUsers()
            // Presentation mapping
            users = domainUsers.map { UserCellModel(name: $0.fullName, avatar: $0.avatarURL) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ========== View (SwiftUI) ==========
struct UserListView: View {
    @StateObject var viewModel: UserListViewModel
    
    var body: some View {
        List(viewModel.users) { user in
            UserRow(model: user)
        }
        .task { await viewModel.fetchUsers() }
    }
}

// ========== View (UIKit + Combine) ==========
class UserListVC: UIViewController {
    private let viewModel: UserListViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: UserListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Binding
        viewModel.$users
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.tableView.reloadData() }
            .store(in: &cancellables)
        
        Task { await viewModel.fetchUsers() }
    }
}
```

**Ưu điểm:** ViewModel testable, tách biệt UI logic. **Hạn chế:** Không quy định rõ navigation, networking nằm ở đâu → dễ bị "Massive ViewModel".

---

### VIPER (View-Interactor-Presenter-Entity-Router)

Chia nhỏ trách nhiệm thành 5 layer riêng biệt, mỗi layer có protocol rõ ràng.

```swift
// ========== Protocols ==========
protocol UserListViewProtocol: AnyObject {
    func showUsers(_ users: [UserCellModel])
    func showError(_ message: String)
    func showLoading()
}

protocol UserListPresenterProtocol {
    func viewDidLoad()
    func didSelectUser(at index: Int)
}

protocol UserListInteractorProtocol {
    func fetchUsers()
}

protocol UserListRouterProtocol {
    func navigateToUserDetail(user: User)
}

// ========== Interactor (Business Logic) ==========
class UserListInteractor: UserListInteractorProtocol {
    weak var presenter: UserListInteractorOutputProtocol?
    private let repository: UserRepositoryProtocol
    
    func fetchUsers() {
        Task {
            do {
                let users = try await repository.getUsers()
                presenter?.didFetchUsers(users)
            } catch {
                presenter?.didFailFetchingUsers(error)
            }
        }
    }
}

// ========== Presenter (Presentation Logic) ==========
class UserListPresenter: UserListPresenterProtocol {
    weak var view: UserListViewProtocol?
    var interactor: UserListInteractorProtocol!
    var router: UserListRouterProtocol!
    private var users: [User] = []
    
    func viewDidLoad() {
        view?.showLoading()
        interactor.fetchUsers()
    }
    
    func didSelectUser(at index: Int) {
        router.navigateToUserDetail(user: users[index])
    }
}

extension UserListPresenter: UserListInteractorOutputProtocol {
    func didFetchUsers(_ users: [User]) {
        self.users = users
        let models = users.map { UserCellModel(name: $0.fullName, avatar: $0.avatarURL) }
        view?.showUsers(models)
    }
    
    func didFailFetchingUsers(_ error: Error) {
        view?.showError(error.localizedDescription)
    }
}

// ========== Router ==========
class UserListRouter: UserListRouterProtocol {
    weak var viewController: UIViewController?
    
    static func createModule() -> UIViewController {
        let vc = UserListViewController()
        let presenter = UserListPresenter()
        let interactor = UserListInteractor(repository: UserRepository())
        let router = UserListRouter()
        
        vc.presenter = presenter
        presenter.view = vc
        presenter.interactor = interactor
        presenter.router = router
        interactor.presenter = presenter
        router.viewController = vc
        return vc
    }
    
    func navigateToUserDetail(user: User) {
        let detailVC = UserDetailRouter.createModule(user: user)
        viewController?.navigationController?.pushViewController(detailVC, animated: true)
    }
}
```

**Ưu điểm:** Mỗi component có trách nhiệm rõ ràng, rất testable. **Hạn chế:** Quá nhiều boilerplate, quá nhiều protocol cho 1 màn hình đơn giản.

---

### Clean Architecture (Robert C. Martin)

Không phải design pattern cụ thể mà là **bộ nguyên tắc tổ chức code** theo layers với **Dependency Rule**: dependency chỉ hướng vào trong (inner layer không biết outer layer).

```
┌──────────────────────────────────────┐
│         Presentation Layer           │  ← UI, ViewModels, ViewControllers
│  ┌──────────────────────────────┐    │
│  │       Domain Layer           │    │  ← UseCases, Entities, Repository Protocols
│  │  ┌──────────────────────┐    │    │
│  │  │   Entity (Core)      │    │    │  ← Pure business models, KHÔNG dependency
│  │  └──────────────────────┘    │    │
│  └──────────────────────────────┘    │
└──────────────────────────────────────┘
         Data Layer                       ← Repository Impl, API, Database, DTO
```

```swift
// ===================================================
// DOMAIN LAYER (innermost - zero dependencies)
// ===================================================

// Entity
struct User {
    let id: String
    let name: String
    let email: String
    var isActive: Bool
}

// Repository Protocol (defined in Domain, implemented in Data)
protocol UserRepositoryProtocol {
    func getUsers() async throws -> [User]
    func getUser(id: String) async throws -> User
}

// Use Case - mỗi use case = 1 business operation
protocol GetUsersUseCaseProtocol {
    func execute() async throws -> [User]
}

class GetUsersUseCase: GetUsersUseCaseProtocol {
    private let repository: UserRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    init(repository: UserRepositoryProtocol, analytics: AnalyticsServiceProtocol) {
        self.repository = repository
        self.analyticsService = analytics
    }
    
    func execute() async throws -> [User] {
        let users = try await repository.getUsers()
        analyticsService.track(.usersLoaded(count: users.count))
        // Business rule: chỉ return active users
        return users.filter { $0.isActive }
    }
}

// ===================================================
// DATA LAYER (outer - implements Domain protocols)
// ===================================================

// DTO (Data Transfer Object)
struct UserDTO: Decodable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let status: String
}

// Mapper: DTO → Domain Entity
extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            name: "\(first_name) \(last_name)",
            email: email,
            isActive: status == "active"
        )
    }
}

// Repository Implementation
class UserRepositoryImpl: UserRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let cache: CacheServiceProtocol
    
    init(apiClient: APIClientProtocol, cache: CacheServiceProtocol) {
        self.apiClient = apiClient
        self.cache = cache
    }
    
    func getUsers() async throws -> [User] {
        // Cache-first strategy
        if let cached: [UserDTO] = cache.get(key: "users") {
            return cached.map { $0.toDomain() }
        }
        let dtos: [UserDTO] = try await apiClient.request(.getUsers)
        cache.set(key: "users", value: dtos, ttl: 300)
        return dtos.map { $0.toDomain() }
    }
    
    func getUser(id: String) async throws -> User {
        let dto: UserDTO = try await apiClient.request(.getUser(id: id))
        return dto.toDomain()
    }
}

// ===================================================
// PRESENTATION LAYER (outer - depends on Domain)
// ===================================================

class UserListViewModel: ObservableObject {
    @Published var users: [UserCellModel] = []
    @Published var state: ViewState = .idle
    
    private let getUsersUseCase: GetUsersUseCaseProtocol
    private let router: AppRouterProtocol
    
    init(getUsersUseCase: GetUsersUseCaseProtocol, router: AppRouterProtocol) {
        self.getUsersUseCase = getUsersUseCase
        self.router = router
    }
    
    @MainActor
    func loadUsers() async {
        state = .loading
        do {
            let domainUsers = try await getUsersUseCase.execute()
            users = domainUsers.map { UserCellModel(from: $0) }
            state = .loaded
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func didTapUser(_ id: String) {
        router.navigate(to: .userDetail(id: id))
    }
}

// ===================================================
// DI Container (wiring everything)
// ===================================================

class AppDIContainer {
    // Data Layer
    lazy var apiClient: APIClientProtocol = APIClient(session: .shared)
    lazy var cacheService: CacheServiceProtocol = InMemoryCache()
    
    // Repositories
    lazy var userRepository: UserRepositoryProtocol = UserRepositoryImpl(
        apiClient: apiClient, cache: cacheService
    )
    
    // Use Cases
    func makeGetUsersUseCase() -> GetUsersUseCaseProtocol {
        GetUsersUseCase(repository: userRepository, analytics: analyticsService)
    }
    
    // ViewModels
    func makeUserListViewModel() -> UserListViewModel {
        UserListViewModel(getUsersUseCase: makeGetUsersUseCase(), router: router)
    }
}
```

---

## 2. Bảng so sánh tổng hợp## 3. Phân tích sâu: Clean Architecture vs từng Architecture

### Clean Architecture vs MVVM

| Khía cạnh | MVVM | Clean Architecture |
|---|---|---|
| **Bản chất** | Presentation pattern (chỉ giải quyết View↔Logic) | Architectural principle (toàn bộ app) |
| **Scope** | Chỉ UI layer | Domain + Data + Presentation |
| **Business Logic** | Nằm trong ViewModel (dễ phình) | Tách riêng UseCase, mỗi case 1 class |
| **Data Access** | VM gọi thẳng service/repository | UseCase → Repository Protocol → Impl |
| **Kết hợp** | **MVVM thường là Presentation layer của Clean Architecture** | Clean Arch dùng MVVM ở Presentation layer |

```swift
// MVVM thuần: ViewModel làm mọi thứ
class OrderViewModel {
    func placeOrder() async {
        let isValid = validateOrder()       // business logic
        let discount = calculateDiscount()  // business logic
        let result = try await api.post()   // data access
        // presentation logic
    }
}

// Clean Arch + MVVM: ViewModel chỉ orchestrate UseCases
class OrderViewModel {
    private let validateOrderUseCase: ValidateOrderUseCaseProtocol
    private let placeOrderUseCase: PlaceOrderUseCaseProtocol
    
    func placeOrder() async {
        guard validateOrderUseCase.execute(order) else { return }
        let result = try await placeOrderUseCase.execute(order)
        // chỉ presentation logic
    }
}
```

**Kết luận:** MVVM và Clean Architecture **không đối lập mà bổ sung cho nhau**. MVVM giải quyết tầng Presentation, Clean Architecture giải quyết toàn bộ kiến trúc.

---

### Clean Architecture vs VIPER

| Khía cạnh | VIPER | Clean Architecture |
|---|---|---|
| **Mức trừu tượng** | Implementation pattern cụ thể | Bộ nguyên tắc (principles) |
| **Cấu trúc** | 5 components cố định per module | Flexible layers, không bắt buộc format |
| **Dependency direction** | Presenter là trung tâm, liên kết 2 chiều | **Strict inward dependency** — Domain không biết gì ngoài |
| **Interactor vs UseCase** | Interactor có thể chứa nhiều operations | Mỗi UseCase chỉ 1 operation (SRP) |
| **Reusability** | Module-level reuse | **Layer-level reuse** — Domain layer dùng lại toàn bộ |

```swift
// VIPER Interactor: nhiều methods, biết Presenter
class UserInteractor: UserInteractorProtocol {
    weak var presenter: UserPresenterProtocol?  // biết outer layer!
    
    func fetchUsers() { ... }
    func deleteUser() { ... }
    func updateUser() { ... }
}

// Clean Architecture UseCase: 1 operation, không biết ai gọi
class FetchUsersUseCase {
    private let repo: UserRepositoryProtocol  // chỉ biết protocol trong cùng layer
    
    func execute() async throws -> [User] {
        return try await repo.getUsers().filter { $0.isActive }
    }
}
```

**Kết luận:** VIPER thực chất là **một cách implement Clean Architecture** nhưng có vài vi phạm Dependency Rule (Interactor biết Presenter). Clean Architecture nghiêm ngặt hơn về dependency direction.

---

### Clean Architecture vs TCA (The Composable Architecture)

| Khía cạnh | TCA | Clean Architecture |
|---|---|---|
| **Paradigm** | Unidirectional data flow (Elm-inspired) | Layered architecture (onion) |
| **State** | Single source of truth, immutable | Distributed across layers |
| **Side Effects** | Effect type, controlled & testable | UseCase orchestrate, tự quản lý |
| **Composability** | Scope & pullback built-in | Manual DI & module composition |
| **SwiftUI** | First-class support | Presentation layer agnostic |
| **Testing** | TestStore exhaustive assertion | Mock protocols, inject dependencies |

```swift
// TCA: State + Action + Reducer + Effect
@Reducer
struct UserListFeature {
    @ObservableState
    struct State: Equatable {
        var users: [User] = []
        var isLoading = false
    }
    
    enum Action {
        case onAppear
        case usersResponse(Result<[User], Error>)
    }
    
    @Dependency(\.userClient) var userClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let result = await Result { try await userClient.getUsers() }
                    await send(.usersResponse(result))
                }
            case .usersResponse(.success(let users)):
                state.isLoading = false
                state.users = users
                return .none
            case .usersResponse(.failure):
                state.isLoading = false
                return .none
            }
        }
    }
}

// Clean Arch: phân tầng rõ ràng, không ràng buộc framework
// Domain layer có thể dùng với TCA, MVVM, hoặc bất kỳ pattern nào
```

**Kết luận:** TCA là **opinionated framework**, Clean Architecture là **bộ principles**. Có thể kết hợp: dùng Clean Architecture cho Domain + Data layers, TCA cho Presentation layer.

---

## 4. Khi nào dùng Architecture nào?

| Tình huống | Khuyến nghị |
|---|---|
| **Prototype / MVP nhỏ** | MVC hoặc MVVM đơn giản |
| **App trung bình, team 2-4 người** | MVVM + Coordinator + Repository |
| **App lớn, team 5+ người** | Clean Architecture (MVVM ở Presentation) |
| **App enterprise, multiple modules** | Clean Architecture + SPM Modularization |
| **SwiftUI-first, state phức tạp** | TCA hoặc Clean Architecture + MVVM |
| **UIKit legacy cần refactor** | Gradual migration: MVC → MVVM → Clean Arch |
| **Team quen VIPER** | VIPER nhưng tuân thủ Dependency Rule của Clean Arch |

---

## 5. Kết hợp thực tế (Production-grade)

Trong thực tế ở các dự án lớn, thường kết hợp nhiều pattern:

```
Clean Architecture Layers:
├── Domain (Pure Swift Package)
│   ├── Entities
│   ├── UseCases (protocols + implementations)
│   └── Repository Protocols
│
├── Data (Swift Package)
│   ├── Repositories (implement Domain protocols)
│   ├── Network (API client, DTOs)
│   ├── Persistence (Core Data, Realm)
│   └── Mappers (DTO ↔ Entity)
│
├── Presentation (App target)
│   ├── MVVM pattern per screen
│   ├── Coordinator pattern for navigation
│   ├── DI Container (Swinject / Factory / manual)
│   └── SwiftUI Views / UIKit VCs
│
└── Infrastructure (Swift Package)
    ├── Logging
    ├── Analytics
    └── Feature Flags
```

Đây chính là **Clean Architecture + MVVM-C (MVVM + Coordinator)**, là pattern phổ biến nhất trong production iOS apps hiện nay.

Bạn muốn mình đi sâu vào phần nào cụ thể không — ví dụ cách modularize Clean Architecture với SPM, hay cách migrate từ VIPER sang Clean Architecture?
