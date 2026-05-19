# The Composable Architecture (TCA) — Giải thích chi tiết

## 1. TCA là gì?

TCA là một **framework kiến trúc** do [Point-Free](https://www.pointfree.co) (Brandon Williams & Stephen Celis) phát triển, được thiết kế để giải quyết các bài toán phổ biến khi xây dựng ứng dụng:

- Quản lý state một cách **nhất quán và dễ dự đoán**
- Chia nhỏ feature thành các phần **độc lập, có thể kết hợp lại** (composable)
- Side effects (gọi API, đọc database...) được **quản lý tường minh**
- **Dễ test** mọi thứ: logic, side effect, thậm chí cả navigation

TCA lấy cảm hứng từ **Redux** (React) và **Elm Architecture**, áp dụng mô hình **unidirectional data flow** vào Swift/SwiftUI.

---

## 2. Unidirectional Data Flow là gì?

### So sánh 2 mô hình:

**Bidirectional (truyền thống — ví dụ MVVM thông thường):**

```
View ←→ ViewModel ←→ Model
  ↕         ↕
 Dữ liệu chảy qua lại, khó trace bug
```

Khi app phức tạp, dữ liệu thay đổi từ nhiều nơi, rất khó biết **"ai đã thay đổi state này, khi nào, và tại sao?"**

**Unidirectional (TCA):**

```
┌─────────────────────────────────────┐
│                                     │
│   User tap button                   │
│         │                           │
│         ▼                           │
│   ┌──────────┐                      │
│   │  Action   │  ← (Sự kiện xảy ra)│
│   └────┬─────┘                      │
│        │                            │
│        ▼                            │
│   ┌──────────┐                      │
│   │ Reducer   │  ← (Xử lý logic)   │
│   └────┬─────┘                      │
│        │                            │
│        ▼                            │
│   ┌──────────┐                      │
│   │  State    │  ← (State mới)      │
│   └────┬─────┘                      │
│        │                            │
│        ▼                            │
│   ┌──────────┐                      │
│   │   View    │  ← (Render lại UI)  │
│   └──────────┘                      │
│        │                            │
│        └── User tap → Action → ...  │
│            (Vòng lặp tiếp tục)      │
└─────────────────────────────────────┘
```

**Dữ liệu chỉ chảy MỘT CHIỀU:** Action → Reducer → State → View → Action → ...

Mọi thay đổi state **bắt buộc** phải đi qua Reducer. Không có ngoại lệ. Điều này làm cho toàn bộ luồng dữ liệu trở nên **dễ dự đoán và dễ debug**.

---

## 3. Bốn thành phần cốt lõi của TCA

### 3.1. State — "Ứng dụng đang ở trạng thái nào?"

Một struct chứa **toàn bộ dữ liệu** mà View cần để hiển thị:

```swift
@Reducer
struct LoginFeature {
    
    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
        var isLoading = false
        var errorMessage: String?
        var isLoggedIn = false
    }
}
```

**Đặc điểm quan trọng:**
- `Equatable` — TCA so sánh state cũ vs mới, chỉ **render lại UI khi state thực sự thay đổi**
- `@ObservableState` — Macro của TCA (từ version 1.7+), giúp SwiftUI tự động observe từng property thay vì toàn bộ struct, tối ưu performance

### 3.2. Action — "Chuyện gì đã xảy ra?"

Một enum liệt kê **tất cả sự kiện** có thể xảy ra trong feature:

```swift
@Reducer
struct LoginFeature {
    // State ở trên...
    
    enum Action: Equatable {
        // User actions (từ UI)
        case emailChanged(String)
        case passwordChanged(String)
        case loginButtonTapped
        
        // System actions (từ side effects)
        case loginResponse(Result<User, Error>)
        
        // Child feature actions
        case forgotPassword(ForgotPasswordFeature.Action)
    }
}
```

**Lưu ý:** Action chỉ **mô tả** chuyện gì đã xảy ra, **KHÔNG** chứa logic xử lý. Giống như bạn nói "Tôi đã bấm nút Login" chứ không phải "Hãy gọi API và lưu token".

### 3.3. Reducer — "Xử lý sự kiện như thế nào?"

Đây là **trái tim** của TCA — nơi chứa toàn bộ business logic:

```swift
@Reducer
struct LoginFeature {
    // State, Action ở trên...
    
    @Dependency(\.authClient) var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
                
            case let .emailChanged(email):
                state.email = email
                return .none  // Không có side effect
                
            case let .passwordChanged(password):
                state.password = password
                return .none
                
            case .loginButtonTapped:
                // Validate
                guard !state.email.isEmpty, !state.password.isEmpty else {
                    state.errorMessage = "Vui lòng nhập đầy đủ thông tin"
                    return .none
                }
                
                state.isLoading = true
                state.errorMessage = nil
                
                // Trả về Effect — side effect được quản lý tường minh
                return .run { [email = state.email, password = state.password] send in
                    let result = await Result {
                        try await self.authClient.login(email, password)
                    }
                    await send(.loginResponse(result))
                }
                
            case let .loginResponse(.success(user)):
                state.isLoading = false
                state.isLoggedIn = true
                return .none
                
            case let .loginResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .forgotPassword:
                return .none  // Delegate cho child reducer
            }
        }
    }
}
```

**Reducer có 2 nhiệm vụ:**
1. **Cập nhật State** — Mutate state trực tiếp (`state.isLoading = true`)
2. **Trả về Effect** — Khai báo side effect cần thực hiện (gọi API, đọc DB...), hoặc `.none` nếu không có

### 3.4. Store — "Nơi kết nối tất cả"

Store giữ state hiện tại, nhận action từ View, chuyển cho Reducer xử lý:

```swift
struct LoginView: View {
    let store: StoreOf<LoginFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            // ... (cách cũ trước TCA 1.7)
        }
    }
}

// ========= TCA 1.7+ với @ObservableState (cách mới, gọn hơn) =========

struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $store.email.sending(\.emailChanged))
            
            SecureField("Password", text: $store.password.sending(\.passwordChanged))
            
            if let error = store.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button("Đăng nhập") {
                store.send(.loginButtonTapped)
            }
            .disabled(store.isLoading)
            
            if store.isLoading {
                ProgressView()
            }
        }
        .padding()
    }
}
```

**Luồng hoạt động hoàn chỉnh:**

```
1. User gõ email "huy@test.com"
2. View gọi: store.send(.emailChanged("huy@test.com"))
3. Reducer nhận action → state.email = "huy@test.com" → return .none
4. State thay đổi → SwiftUI tự động render lại TextField

5. User tap "Đăng nhập"  
6. View gọi: store.send(.loginButtonTapped)
7. Reducer:
   - state.isLoading = true  →  UI hiện ProgressView
   - return .run { ... gọi API ... send(.loginResponse(result)) }
8. API trả về thành công
9. Reducer nhận .loginResponse(.success(user)):
   - state.isLoading = false
   - state.isLoggedIn = true
   → UI ẩn ProgressView, chuyển màn hình
```

---

## 4. Effect — Quản lý Side Effect tường minh

Đây là điểm TCA khác biệt lớn so với MVVM thông thường. Mọi side effect (gọi API, đọc file, timer, location...) đều được **khai báo tường minh** và trả về từ Reducer:

```swift
// ❌ MVVM thông thường — side effect nằm rải rác
class LoginViewModel: ObservableObject {
    func login() {
        Task {
            let user = try await apiClient.login(...)  // Side effect ẩn bên trong
            self.user = user                            // Mutate state trực tiếp
        }
    }
}

// ✅ TCA — side effect được khai báo tường minh, trả về từ Reducer
case .loginButtonTapped:
    state.isLoading = true
    return .run { send in
        // Side effect được "đẩy ra ngoài" Reducer
        let result = await Result { try await authClient.login(...) }
        await send(.loginResponse(result))  // Kết quả quay lại qua Action
    }
```

**Tại sao điều này quan trọng?** Vì khi test, bạn có thể **kiểm soát hoàn toàn** side effect xảy ra hay không, trả về gì.

---

## 5. Dependency Management

TCA có hệ thống **Dependency Injection** tích hợp sẵn:

```swift
// 1. Khai báo dependency
struct AuthClient {
    var login: (String, String) async throws -> User
    var logout: () async throws -> Void
}

// 2. Đăng ký với DependencyValues
extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClientKey.self] }
        set { self[AuthClientKey.self] = newValue }
    }
}

// 3. Cung cấp implementation thật
extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        login: { email, password in
            try await APIService.shared.login(email: email, password: password)
        },
        logout: {
            try await APIService.shared.logout()
        }
    )
    
    // Implementation cho test
    static let testValue = AuthClient(
        login: { _, _ in User.mock },
        logout: { }
    )
    
    // Implementation cho Preview
    static let previewValue = AuthClient(
        login: { _, _ in
            try await Task.sleep(for: .seconds(1))
            return User.mock
        },
        logout: { }
    )
}

// 4. Sử dụng trong Reducer
@Reducer
struct LoginFeature {
    @Dependency(\.authClient) var authClient  // Tự động inject
}
```

Khi chạy app thật → dùng `liveValue`. Khi test → tự động dùng `testValue`. Khi Preview → dùng `previewValue`. Không cần truyền dependency thủ công.

---

## 6. Composition — Kết hợp nhiều Feature

Đây là chữ **"Composable"** trong tên TCA — khả năng ghép nhiều feature nhỏ thành feature lớn:

```swift
// Feature con: Quản lý danh sách sản phẩm
@Reducer
struct ProductListFeature {
    @ObservableState
    struct State: Equatable {
        var products: [Product] = []
        var isLoading = false
    }
    enum Action {
        case onAppear
        case productsLoaded([Product])
        case productTapped(Product)
    }
    // Reducer...
}

// Feature con: Giỏ hàng
@Reducer
struct CartFeature {
    @ObservableState
    struct State: Equatable {
        var items: [CartItem] = []
        var totalPrice: Decimal = 0
    }
    enum Action {
        case addItem(Product)
        case removeItem(CartItem)
        case checkout
    }
    // Reducer...
}

// Feature cha: Kết hợp cả 2
@Reducer
struct ShopFeature {
    @ObservableState
    struct State: Equatable {
        var productList = ProductListFeature.State()
        var cart = CartFeature.State()
        var selectedTab: Tab = .products
    }
    
    enum Action {
        case productList(ProductListFeature.Action)
        case cart(CartFeature.Action)
        case tabChanged(Tab)
    }
    
    var body: some ReducerOf<Self> {
        
        // Gắn child reducers
        Scope(state: \.productList, action: \.productList) {
            ProductListFeature()
        }
        Scope(state: \.cart, action: \.cart) {
            CartFeature()
        }
        
        // Parent reducer — xử lý giao tiếp giữa các child
        Reduce { state, action in
            switch action {
            case let .productList(.productTapped(product)):
                // Khi user tap sản phẩm ở danh sách → thêm vào giỏ hàng
                state.cart.items.append(CartItem(product: product, quantity: 1))
                state.cart.totalPrice += product.price
                return .none
                
            case .tabChanged(let tab):
                state.selectedTab = tab
                return .none
                
            default:
                return .none
            }
        }
    }
}
```

**Mô hình cây:**

```
ShopFeature (cha)
├── ProductListFeature (con)
└── CartFeature (con)

- Mỗi con có State/Action/Reducer riêng, test riêng
- Cha kết nối chúng qua Scope
- Cha "nghe" action của con để xử lý giao tiếp
```

Bạn có thể lồng nhiều tầng: `AppFeature → TabFeature → ShopFeature → ProductListFeature`. Mỗi tầng quản lý phần state và logic của mình.

---

## 7. Testing — Thế mạnh lớn nhất của TCA

TCA cung cấp `TestStore` giúp test **cực kỳ rõ ràng và chi tiết**:

```swift
@Test
func testLoginSuccess() async {
    let store = TestStore(
        initialState: LoginFeature.State()
    ) {
        LoginFeature()
    } withDependencies: {
        // Inject mock dependency
        $0.authClient.login = { _, _ in
            User(id: "1", name: "Huy", email: "huy@test.com")
        }
    }
    
    // Gửi action và ASSERT chính xác state thay đổi như thế nào
    await store.send(.emailChanged("huy@test.com")) {
        $0.email = "huy@test.com"  // Expect: email = "huy@test.com"
    }
    
    await store.send(.passwordChanged("123456")) {
        $0.password = "123456"
    }
    
    await store.send(.loginButtonTapped) {
        $0.isLoading = true    // Expect: isLoading chuyển thành true
        $0.errorMessage = nil
    }
    
    // Assert: nhận response từ effect
    await store.receive(\.loginResponse.success) {
        $0.isLoading = false   // Expect: isLoading = false
        $0.isLoggedIn = true   // Expect: isLoggedIn = true
    }
}

@Test
func testLoginFailure() async {
    let store = TestStore(
        initialState: LoginFeature.State()
    ) {
        LoginFeature()
    } withDependencies: {
        $0.authClient.login = { _, _ in
            throw AuthError.invalidCredentials
        }
    }
    
    await store.send(.emailChanged("wrong@test.com")) { $0.email = "wrong@test.com" }
    await store.send(.passwordChanged("wrong")) { $0.password = "wrong" }
    
    await store.send(.loginButtonTapped) {
        $0.isLoading = true
        $0.errorMessage = nil
    }
    
    await store.receive(\.loginResponse.failure) {
        $0.isLoading = false
        $0.errorMessage = "Invalid credentials"
    }
}
```

**Điều đặc biệt:** `TestStore` sẽ **fail test** nếu:
- Bạn quên assert một state change
- Có effect chạy mà bạn không `receive`
- State thay đổi khác với expectation

Điều này đảm bảo test **exhaustive** — không bỏ sót bất kỳ thay đổi nào.

---

## 8. Tại sao TCA phù hợp với SwiftUI?

| Đặc điểm SwiftUI | TCA đáp ứng như thế nào |
|---|---|
| Declarative UI — UI là hàm của State | TCA enforce State → View một chiều, View chỉ đọc state và gửi action |
| Value types (struct-based views) | State là struct, Action là enum — tất cả value types |
| `@Observable` / property observation | `@ObservableState` macro tự động tối ưu, chỉ re-render khi property thay đổi |
| Preview | `previewValue` cho dependency, dễ tạo Preview với bất kỳ state nào |
| Navigation API (NavigationStack) | TCA có navigation tools tích hợp, quản lý navigation state trong State |

---

## 9. Trade-offs — Khi nào nên / không nên dùng TCA

**Nên dùng khi:**
- App trung bình → lớn, nhiều feature phức tạp tương tác với nhau
- Team cần convention rõ ràng, mọi người code theo cùng một pattern
- Cần test coverage cao, đặc biệt business logic
- App có nhiều side effects phức tạp cần quản lý chặt chẽ

**Cân nhắc kỹ khi:**
- App nhỏ, đơn giản — TCA có thể overkill, tạo quá nhiều boilerplate
- Team chưa quen functional programming — learning curve khá dốc
- Cần tốc độ phát triển nhanh cho MVP/prototype
- TCA update thường xuyên, đôi khi có breaking changes giữa các version

---

## 10. Tổng kết bằng một dòng

> TCA là một **kiến trúc unidirectional** biến toàn bộ app thành một **cây State + Reducer có thể compose**, nơi mọi thay đổi đều đi qua một con đường duy nhất, mọi side effect đều được khai báo tường minh, và mọi thứ đều có thể test được.

Bạn muốn mình đi sâu hơn vào phần nào? Ví dụ: Navigation trong TCA, cách handle Optional state (`.ifLet`, `.forEach`), hay so sánh chi tiết TCA vs MVVM trong production?
