# So sánh Clean Swift (VIP) vs The Composable Architecture (TCA) trong SwiftUI

Đây là hai kiến trúc đến từ hai trường phái triết lý hoàn toàn khác nhau. Việc so sánh không chỉ là so syntax mà còn là so cách tư duy về **state**, **side effects**, và **composition**.

---

## 1. Triết lý nền tảng

**Clean Swift (VIP)** ra đời từ Raymond Law như một phiên bản đơn giản hóa của Clean Architecture cho UIKit. Trọng tâm là **scene-based isolation** — mỗi màn hình là một "scene" tự đóng kín với chu trình `View → Interactor → Presenter → View`. Mỗi scene độc lập, ít quan tâm đến scene khác. Đây là kiến trúc thiên về **OOP với protocol boundaries**.

**TCA** do Point-Free (Brandon Williams & Stephen Celis) thiết kế, lấy cảm hứng từ Elm/Redux nhưng "Swift-native" với value types và type system mạnh. Trọng tâm là **feature composition** — một feature có thể là một button hoặc cả app, và bạn ghép chúng lại như Lego. Đây là kiến trúc thiên về **functional programming** với unidirectional data flow nghiêm ngặt.

Sự khác biệt cốt lõi: Clean Swift hỏi *"Làm sao để tách layer trong một màn hình?"*, còn TCA hỏi *"Làm sao để compose state và behavior xuyên suốt cả app?"*.

---

## 2. Cấu trúc components

### Clean Swift (VIP) trong SwiftUI

Khi đưa Clean Swift vào SwiftUI, việc "ViewController" biến mất tạo ra adaptation. Pattern phổ biến là biến `View` thành SwiftUI view, dùng `ObservableObject` làm cầu nối giữa Presenter output và View:

```swift
// MARK: - Models
enum LoginScene {
    enum Login {
        struct Request {
            let email: String
            let password: String
        }
        struct Response {
            let result: Result<User, AuthError>
        }
        struct ViewModel {
            let isLoading: Bool
            let errorMessage: String?
            let userName: String?
        }
    }
}

// MARK: - Interactor
protocol LoginBusinessLogic {
    func login(request: LoginScene.Login.Request)
}

final class LoginInteractor: LoginBusinessLogic {
    var presenter: LoginPresentationLogic?
    var worker: AuthWorker = AuthWorker()
    
    func login(request: LoginScene.Login.Request) {
        Task {
            do {
                let user = try await worker.authenticate(
                    email: request.email,
                    password: request.password
                )
                let response = LoginScene.Login.Response(result: .success(user))
                await MainActor.run {
                    presenter?.presentLogin(response: response)
                }
            } catch let error as AuthError {
                let response = LoginScene.Login.Response(result: .failure(error))
                await MainActor.run {
                    presenter?.presentLogin(response: response)
                }
            }
        }
    }
}

// MARK: - Presenter
protocol LoginPresentationLogic {
    func presentLogin(response: LoginScene.Login.Response)
}

final class LoginPresenter: LoginPresentationLogic, ObservableObject {
    @Published var viewModel = LoginScene.Login.ViewModel(
        isLoading: false,
        errorMessage: nil,
        userName: nil
    )
    
    func presentLogin(response: LoginScene.Login.Response) {
        switch response.result {
        case .success(let user):
            viewModel = .init(isLoading: false, errorMessage: nil, userName: user.name)
        case .failure(let error):
            viewModel = .init(isLoading: false, errorMessage: error.localizedDescription, userName: nil)
        }
    }
}

// MARK: - View
struct LoginView: View {
    @StateObject private var presenter = LoginPresenter()
    @State private var email = ""
    @State private var password = ""
    
    private let interactor: LoginBusinessLogic
    
    init() {
        let presenter = LoginPresenter()
        let interactor = LoginInteractor()
        interactor.presenter = presenter
        self.interactor = interactor
        self._presenter = StateObject(wrappedValue: presenter)
    }
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            Button("Login") {
                interactor.login(request: .init(email: email, password: password))
            }
            if let error = presenter.viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
    }
}
```

Vấn đề ngay lập tức nhìn thấy: SwiftUI view không phải class, không có lifecycle như `UIViewController`, nên việc wiring `interactor.presenter = presenter` trở nên awkward trong `init()`. Đây là **một trong những điểm friction lớn nhất** của Clean Swift trong SwiftUI.

### TCA trong SwiftUI

TCA dùng macro hiện đại (TCA 1.x trở đi) nên syntax rất gọn:

```swift
import ComposableArchitecture

@Reducer
struct LoginFeature {
    @ObservableState
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var isLoading: Bool = false
        var errorMessage: String?
        var userName: String?
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case loginButtonTapped
        case loginResponse(Result<User, AuthError>)
    }
    
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .loginButtonTapped:
                state.isLoading = true
                state.errorMessage = nil
                return .run { [email = state.email, password = state.password] send in
                    await send(.loginResponse(
                        Result { try await authClient.login(email, password) }
                    ))
                }
                
            case let .loginResponse(.success(user)):
                state.isLoading = false
                state.userName = user.name
                return .none
                
            case let .loginResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}

struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    
    var body: some View {
        VStack {
            TextField("Email", text: $store.email)
            SecureField("Password", text: $store.password)
            Button("Login") {
                store.send(.loginButtonTapped)
            }
            .disabled(store.isLoading)
            
            if let error = store.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
    }
}
```

Code TCA ngắn hơn đáng kể vì binding được sinh tự động, side effect được mô tả declarative qua `Effect`, và toàn bộ state nằm trong một struct duy nhất.

---

## 3. State management

| Khía cạnh | Clean Swift | TCA |
|---|---|---|
| **Source of truth** | Phân tán: state nằm trong Interactor (business state), Presenter (view state), và `@State` của View | Tập trung: một `State` struct duy nhất per feature |
| **Mutability** | Reference types (class), mutable in place | Value types (struct), mutate qua `inout` trong reducer |
| **Cross-feature state** | Không có pattern chuẩn — thường dùng singleton/shared service | `Scope` reducer + parent-child State composition |
| **Observability** | `@Published` trong Presenter, manual setup | `@ObservableState` macro tự sinh observation |
| **Time travel debugging** | Không có | Có sẵn (state là Equatable + replay được) |

State trong Clean Swift mang tính **implicit** — bạn phải đọc cả Interactor lẫn Presenter mới biết "trạng thái thật" của feature. TCA mang tính **explicit** — nhìn vào `State` struct là biết toàn bộ.

---

## 4. Side effects

Đây là khác biệt quan trọng nhất về mặt kỹ thuật.

**Clean Swift** xử lý side effects qua **Worker** — một class thường chứa async/await hoặc Combine. Worker được Interactor gọi trực tiếp, kết quả được callback ngược về Presenter. Side effect không có "type" cụ thể, chỉ là method call thông thường.

**TCA** mô hình hóa side effect thành kiểu `Effect<Action>` — first-class citizen. Mọi side effect (network, timer, animation, navigation) đều được mô tả declarative và return từ reducer. Reducer là pure function: `(inout State, Action) -> Effect<Action>`. Điều này cho phép:

```swift
// Cancel effect
case .searchTextChanged:
    return .run { [query = state.query] send in
        try await Task.sleep(for: .milliseconds(300))
        await send(.searchResponse(try await api.search(query)))
    }
    .cancellable(id: CancelID.search, cancelInFlight: true)

// Merge effects
case .onAppear:
    return .merge(
        .run { send in await send(.fetchProfile) },
        .run { send in await send(.fetchSettings) }
    )

// Run effects sequentially
case .checkout:
    return .concatenate(
        .run { send in await send(.validateCart) },
        .run { send in await send(.processPayment) },
        .run { send in await send(.sendReceipt) }
    )
```

Trong Clean Swift, để làm cancel/merge/sequence như trên bạn phải **tự tay** quản lý `Task` hoặc `AnyCancellable` trong Worker — dễ leak, dễ race condition.

---

## 5. Composition

Đây là vùng mà Clean Swift **hoàn toàn không có câu trả lời tốt**. Khi bạn có 5 màn hình cần chia sẻ state (ví dụ: cart icon ở navbar phản ánh trạng thái cart đang được edit ở màn hình khác), Clean Swift buộc bạn dùng:
- Singleton service
- Notification/Combine publisher manual
- Hoặc copy data qua Router

TCA giải quyết vấn đề này bằng **reducer composition**:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var tabs: TabsFeature.State = .init()
        var cart: CartFeature.State = .init()  // shared cart
        var profile: ProfileFeature.State = .init()
    }
    
    enum Action {
        case tabs(TabsFeature.Action)
        case cart(CartFeature.Action)
        case profile(ProfileFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.tabs, action: \.tabs) { TabsFeature() }
        Scope(state: \.cart, action: \.cart) { CartFeature() }
        Scope(state: \.profile, action: \.profile) { ProfileFeature() }
        
        // Cross-cutting logic
        Reduce { state, action in
            switch action {
            case .profile(.logoutTapped):
                state.cart = .init()  // reset cart on logout
                return .none
            default:
                return .none
            }
        }
    }
}
```

Composition trong TCA là **first-class**. Trong Clean Swift, đây là pain point thực sự ở dự án lớn.

---

## 6. Testing

**Clean Swift** test theo kiểu truyền thống: mock `Worker`, mock `Presenter` (qua protocol), gọi method trên `Interactor`, assert spy được gọi đúng. Test pass nhưng verbose, nhiều mock class.

```swift
final class LoginInteractorTests: XCTestCase {
    func test_login_success() async {
        let presenterSpy = LoginPresenterSpy()
        let workerStub = AuthWorkerStub(result: .success(User(name: "Huy")))
        let sut = LoginInteractor()
        sut.presenter = presenterSpy
        sut.worker = workerStub
        
        sut.login(request: .init(email: "a@b.com", password: "x"))
        
        await fulfillment(of: [presenterSpy.expectation], timeout: 1)
        XCTAssertEqual(presenterSpy.receivedResponse?.result, .success(...))
    }
}
```

**TCA** có `TestStore` — một construct cực mạnh ép bạn assert **mọi** state change và **mọi** action effect:

```swift
@MainActor
final class LoginFeatureTests: XCTestCase {
    func test_login_success() async {
        let store = TestStore(initialState: LoginFeature.State()) {
            LoginFeature()
        } withDependencies: {
            $0.authClient.login = { _, _ in User(name: "Huy") }
        }
        
        await store.send(.binding(.set(\.email, "a@b.com"))) {
            $0.email = "a@b.com"
        }
        await store.send(.binding(.set(\.password, "x"))) {
            $0.password = "x"
        }
        await store.send(.loginButtonTapped) {
            $0.isLoading = true
        }
        await store.receive(\.loginResponse.success) {
            $0.isLoading = false
            $0.userName = "Huy"
        }
    }
}
```

Nếu state thay đổi không đúng như mô tả, hoặc có effect chưa được receive, test **fail**. Đây là exhaustive testing — chất lượng test cao hơn nhiều so với mock-based, nhưng cũng đòi hỏi viết kỹ hơn.

---

## 7. SwiftUI integration

| Aspect | Clean Swift | TCA |
|---|---|---|
| **Native fit với SwiftUI** | Awkward — ViewController không tồn tại, Router phải redesign | Native — thiết kế cho SwiftUI từ đầu |
| **Navigation** | Router pattern khó port (UIKit-based) | `NavigationStack` + `@Presents` macro, declarative |
| **Bindings** | Manual `$` bindings vào `@Published` | Tự động qua `@Bindable` + `BindableAction` |
| **Animation** | Tự handle qua `withAnimation` ở View | `Effect.run` + `Animation` parameter trong send |
| **Lifecycle** | Phải dùng `.onAppear`/`.task` để trigger Interactor | `.task` gọi `store.send(.task)` rất tự nhiên |

---

## 8. Bảng tổng hợp trade-offs

| Tiêu chí | Clean Swift | TCA |
|---|---|---|
| **Learning curve** | Trung bình (OOP + protocol) | Cao (FP, reducer, effect) |
| **Boilerplate** | Cao (Request/Response/ViewModel cho mỗi use case) | Trung bình (giảm nhiều nhờ macros 1.x) |
| **Type safety** | Tốt | Rất cao (exhaustive enum Action) |
| **Compile time** | Nhanh | Chậm hơn (generic-heavy, macro expansion) |
| **Bundle size impact** | 0 (no dependency) | ~2-3MB (TCA + dependencies) |
| **iOS version** | Không yêu cầu | iOS 13+ (Observation macro: iOS 17+, có fallback) |
| **Composability** | Yếu | Rất mạnh |
| **Testability** | Khá (mock-based) | Xuất sắc (TestStore exhaustive) |
| **Debugging** | Print/breakpoint thông thường | Built-in `_printChanges()`, time-travel |
| **Modern Swift features** | Cập nhật chậm | Tận dụng macro, Observation, Swift Concurrency tích cực |
| **Team onboarding** | Dễ với dev quen UIKit/VIPER | Cần training nếu team chưa quen Redux/Elm |
| **Maintained by** | Community (chậm cập nhật) | Point-Free (cập nhật rất tích cực) |

---

## 9. Pitfalls thực tế

### Clean Swift pitfalls trong SwiftUI

1. **Init wiring khó chịu** — không có `awakeFromNib` hay `viewDidLoad`, phải dùng `init` của View hoặc factory function. Nếu dùng `@StateObject`, careful với reference cycle giữa Interactor ↔ Presenter.
2. **Router gần như vô nghĩa** — SwiftUI navigation declarative, Router pattern UIKit không port được tự nhiên.
3. **Boilerplate Request/Response/ViewModel** trở nên quá nặng cho feature nhỏ. Một button toggle cũng cần 3 model + Interactor + Presenter.
4. **Cross-scene state** — không có giải pháp chuẩn, dễ fall back vào singleton.

### TCA pitfalls

1. **Performance trap với big state** — toàn bộ State là value type nên copy-on-write. State quá lớn (mảng nghìn phần tử) trong reducer có thể chậm. Giải pháp: chia nhỏ feature, dùng `IdentifiedArray`, hoặc giữ data nặng ngoài State (qua dependency client).
2. **Action enum bùng nổ** — dự án lớn dễ có Action enum 50+ case. Cần discipline tách nested enum hoặc subdivide reducers.
3. **Compile time** — generic-heavy code khiến Xcode build chậm. Project lớn nên cẩn thận với explicit return types và modularize.
4. **Effect lifecycle** — quên `.cancellable` và race condition giữa effects là bug thường gặp. Đặc biệt với search/typing flows.
5. **Over-modularize sớm** — nhiều team chia feature quá nhỏ ngay từ đầu, làm parent reducer phức tạp. Nên start coarse, refactor khi cần.
6. **Macro debugging** — khi `@Reducer` hoặc `@ObservableState` lỗi, error message từ Swift compiler thường khó hiểu.

---

## 10. Khi nào dùng cái nào?

**Chọn Clean Swift khi:**
- Codebase UIKit hiện tại đã dùng Clean Swift, đang migrate dần sang SwiftUI
- Team đã quen VIPER/VIP, không muốn đổi mindset sang FP
- Yêu cầu strict layered architecture từ stakeholder/architect (ví dụ banking, government project)
- Không muốn add 3rd-party dependency
- App đơn giản, mỗi màn hình độc lập, ít cross-feature state

**Chọn TCA khi:**
- Dự án SwiftUI mới (greenfield)
- App phức tạp với nhiều cross-feature state (e-commerce, social, fintech)
- Team đề cao testability — muốn exhaustive coverage
- Có nhu cầu state restoration, deep linking, undo/redo
- Team OK với learning curve và maintenance overhead của 3rd-party
- Cần composability cao (modular feature, app extension dùng chung feature)

**Tránh TCA khi:**
- App rất nhỏ (todo list, prototype) — overkill
- Team chưa từng làm Redux/Elm và không có thời gian training
- Yêu cầu support iOS 12 hoặc thấp hơn
- Constraint binary size khắt khe

**Tránh Clean Swift khi:**
- Project SwiftUI thuần, không có legacy UIKit
- Cần composability mạnh
- Team trẻ, không quen patterns cũ — cost training Clean Swift cũng không nhỏ và return ít hơn TCA

---

## Kết luận ngắn

Clean Swift là **kiến trúc của thời UIKit**, gồng mình adapt sang SwiftUI và mất đi nhiều thế mạnh ban đầu (Router, scene isolation rõ ràng nhờ ViewController lifecycle). Nó vẫn dùng được nhưng không phải lựa chọn tự nhiên cho SwiftUI mới.

TCA là **kiến trúc thiết kế cho SwiftUI** — tận dụng value types, Swift Concurrency, macros, và observation. Cost là learning curve và một dependency lớn, nhưng đổi lại bạn được composability, testability, và state predictability ở level mà Clean Swift không thể đạt được.

Với một dự án SwiftUI mới ở quy mô vừa-lớn, **TCA là lựa chọn rational hơn**. Clean Swift chỉ thực sự hợp lý khi có constraint về team, legacy, hoặc dependency policy.
