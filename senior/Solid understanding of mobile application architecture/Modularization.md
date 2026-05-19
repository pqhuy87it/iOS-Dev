# Modularization trong iOS — Giải thích chi tiết

## 1. Modularization là gì?

Hãy tưởng tượng ứng dụng của bạn như một **ngôi nhà**. Thay vì xây một khối bê tông nguyên khối (monolith), bạn chia thành các phòng riêng biệt: phòng khách, phòng bếp, phòng ngủ... Mỗi phòng có chức năng riêng, hoạt động độc lập, nhưng kết nối với nhau qua cửa và hành lang.

Modularization trong iOS cũng vậy — bạn **tách codebase thành các module riêng biệt**, mỗi module đảm nhận một trách nhiệm cụ thể và có thể được develop, build, test độc lập.

---

## 2. Tại sao cần Modularization?

### Với một app monolith (không modular):

```
MyApp/
├── AppDelegate.swift
├── LoginViewController.swift
├── LoginViewModel.swift
├── HomeViewController.swift
├── HomeViewModel.swift
├── ProductDetailViewController.swift
├── NetworkManager.swift
├── CoreDataManager.swift
├── UIComponents/
├── ... (hàng trăm file nằm chung)
```

**Vấn đề phát sinh khi app lớn dần:**

- **Build time cực lâu** — Sửa 1 file, Xcode build lại gần như toàn bộ project. Với app lớn có thể mất 5-10 phút mỗi lần build.
- **Merge conflict liên tục** — 10 developer cùng làm việc trên 1 project file (.xcodeproj), conflict xảy ra hàng ngày.
- **Không có ranh giới rõ ràng** — Feature A dễ dàng `import` và gọi trực tiếp code của Feature B, tạo ra sự phụ thuộc chằng chịt (spaghetti dependencies).
- **Không thể test độc lập** — Muốn test Login thì phải build cả phần Home, Product, Networking...
- **Onboard chậm** — Developer mới phải hiểu cả codebase khổng lồ trước khi bắt đầu làm việc.

---

## 3. Cấu trúc một app đã Modularized

```
MyApp/
│
├── App/                        ← Main app (chỉ là "vỏ", kết nối các module)
│   ├── AppDelegate.swift
│   └── AppCoordinator.swift
│
├── Modules/
│   ├── Core/                   ← Dùng chung cho TẤT CẢ module
│   │   ├── Networking/         ← API client, request/response handling
│   │   ├── Storage/            ← CoreData, Keychain, UserDefaults wrapper
│   │   ├── Common/             ← Extensions, Utilities, Constants
│   │   └── Domain/             ← Shared models, protocols, use cases
│   │
│   ├── UIKit/                  ← Design System
│   │   ├── DesignTokens/       ← Colors, Fonts, Spacing
│   │   └── Components/         ← Button, TextField, Card... (reusable UI)
│   │
│   ├── FeatureLogin/           ← Feature module
│   │   ├── Sources/
│   │   │   ├── LoginView.swift
│   │   │   ├── LoginViewModel.swift
│   │   │   └── LoginRepository.swift
│   │   ├── Tests/
│   │   │   └── LoginViewModelTests.swift
│   │   └── Package.swift
│   │
│   ├── FeatureHome/            ← Feature module
│   │   ├── Sources/
│   │   ├── Tests/
│   │   └── Package.swift
│   │
│   └── FeatureProduct/         ← Feature module
│       ├── Sources/
│       ├── Tests/
│       └── Package.swift
```

---

## 4. Các loại Module thường gặp

### 4.1. Core Module (Nền tảng)

Chứa những thứ mà **mọi feature đều cần dùng**:

```swift
// Module: Networking
// Cung cấp API client cho tất cả feature modules

public protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

public final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let baseURL: URL
    
    public init(session: URLSession = .shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }
    
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try endpoint.buildRequest(baseURL: baseURL)
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

**Lưu ý quan trọng:** Từ khóa `public` — trong modularization, bạn phải **chủ động quyết định** cái gì được "public" ra ngoài cho module khác dùng. Mặc định trong Swift là `internal` (chỉ truy cập được trong cùng module).

### 4.2. UI/Design System Module

```swift
// Module: DesignSystem
// Cung cấp UI components thống nhất cho toàn app

public struct AppButton: View {
    public enum Style {
        case primary, secondary, destructive
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    
    public init(title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.buttonTitle)  // Dùng font token chung
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.medium)
                .background(backgroundColor)
                .cornerRadius(AppRadius.medium)
        }
    }
}
```

Mọi feature module chỉ cần `import DesignSystem` là có thể dùng `AppButton`, đảm bảo UI **nhất quán** trên toàn app.

### 4.3. Feature Module

Đây là phần quan trọng nhất — mỗi feature là một module **khép kín**:

```swift
// Module: FeatureLogin
// Package.swift

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureLogin",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureLogin", targets: ["FeatureLogin"])
    ],
    dependencies: [
        .package(path: "../Core/Networking"),
        .package(path: "../Core/Domain"),
        .package(path: "../DesignSystem")
        // ⚠️ KHÔNG depend vào FeatureHome, FeatureProduct...
    ],
    targets: [
        .target(
            name: "FeatureLogin",
            dependencies: ["Networking", "Domain", "DesignSystem"]
        ),
        .testTarget(
            name: "FeatureLoginTests",
            dependencies: ["FeatureLogin"]
        )
    ]
)
```

```swift
// FeatureLogin/Sources/LoginViewModel.swift

import Networking
import Domain

public final class LoginViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let authRepository: AuthRepositoryProtocol
    
    // Dependency Injection — nhận repository từ bên ngoài
    public init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }
    
    public func login() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let user = try await authRepository.login(
                email: email,
                password: password
            )
            // Thông báo login thành công
            // (qua delegate/closure/notification — KHÔNG navigate trực tiếp)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## 5. Giao tiếp giữa các Feature Module

Đây là phần **khó nhất** của modularization. Các feature module **không được biết nhau**, vậy làm sao FeatureLogin chuyển sang FeatureHome sau khi đăng nhập?

### Cách 1: Public Interface (Protocol) ở Core Module

```swift
// Module: Domain (Core)
// Định nghĩa "hợp đồng" mà các module sẽ tuân theo

public protocol LoginOutputDelegate: AnyObject {
    func loginDidSucceed(user: User)
    func loginDidRequestSignUp()
}

public protocol ProductDetailRouting {
    func showProductDetail(productId: String)
}
```

```swift
// Module: FeatureLogin — chỉ biết protocol, không biết ai implement

public final class LoginViewModel: ObservableObject {
    public weak var delegate: LoginOutputDelegate?
    
    public func login() async {
        // ... sau khi login thành công
        delegate?.loginDidSucceed(user: user)
    }
}
```

```swift
// Module: App — nơi DUY NHẤT biết tất cả module, kết nối chúng lại

class AppCoordinator: LoginOutputDelegate {
    func loginDidSucceed(user: User) {
        // Chuyển sang HomeModule
        let homeView = HomeModule.makeHomeView(user: user)
        navigationController.setViewControllers([homeView], animated: true)
    }
}
```

### Cách 2: Dependency Container tại App level

```swift
// Module: App

@main
struct MyApp: App {
    
    // Tạo tất cả dependencies ở đây
    let container = DependencyContainer()
    
    init() {
        // Đăng ký tất cả dependencies
        container.register(APIClientProtocol.self) {
            APIClient(baseURL: Environment.apiBaseURL)
        }
        container.register(AuthRepositoryProtocol.self) {
            AuthRepository(apiClient: container.resolve())
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // Inject dependency vào feature module
            LoginView(
                viewModel: LoginViewModel(
                    authRepository: container.resolve()
                )
            )
        }
    }
}
```

---

## 6. Dependency Graph — Quy tắc vàng

```
App (biết tất cả)
 ├── FeatureLogin ──┐
 ├── FeatureHome ───┤──→ Core (Networking, Domain, Storage)
 ├── FeatureProduct ┘        │
 │                     DesignSystem
 │
 ⚠️ QUY TẮC:
 │  ✅ Feature → Core         (OK)
 │  ✅ Feature → DesignSystem  (OK)
 │  ✅ App → Feature           (OK)
 │  ❌ Feature → Feature       (KHÔNG BAO GIỜ)
 │  ❌ Core → Feature          (KHÔNG BAO GIỜ)
```

Nếu **FeatureLogin import FeatureHome**, bạn đã phá vỡ modularization. Hai module sẽ phụ thuộc lẫn nhau, không thể build/test độc lập nữa.

---

## 7. Công cụ để Modularize trên iOS

**Swift Package Manager (SPM)** — Cách phổ biến nhất hiện tại. Mỗi module là một local Swift Package. Xcode hỗ trợ tốt, quản lý dependency rõ ràng qua `Package.swift`.

**Xcode Frameworks** — Cách truyền thống hơn. Tạo mỗi module thành một framework target trong Xcode. Cấu hình phức tạp hơn SPM nhưng linh hoạt hơn trong một số trường hợp.

**Tuist** — Tool tự động generate Xcode project từ file cấu hình Swift. Rất mạnh cho project lớn, giúp quản lý module, dependency graph, và giảm conflict file `.xcodeproj`.

---

## 8. Lợi ích thực tế

| Vấn đề | Monolith | Modularized |
|---|---|---|
| Build time (incremental) | 3-10 phút | 10-30 giây (chỉ build module bị thay đổi) |
| Chạy Unit Test | Chạy cả project | Chạy riêng module, nhanh hơn 5-10x |
| Merge conflict | Thường xuyên | Hiếm (mỗi team làm module riêng) |
| Code coupling | Cao, khó kiểm soát | Thấp, được enforce bởi access control |
| Onboard dev mới | Phải hiểu toàn bộ | Chỉ cần hiểu module được assign |

---

## 9. Khi nào nên Modularize?

**Không cần modularize** khi: app nhỏ, 1-2 developer, prototype/MVP, ít tính năng.

**Nên modularize** khi: team từ 3-4 người trở lên, app có nhiều feature độc lập, build time bắt đầu chậm (trên 1-2 phút), hoặc bạn muốn reuse module cho app khác (ví dụ: share Networking module giữa main app và widget extension).

**Modularize dần dần** — Không cần tách hết một lúc. Bắt đầu bằng cách tách Core (Networking, Storage) ra trước, sau đó tách DesignSystem, rồi mới tách từng feature module. Đây là cách thực tế nhất trong thực tế production.

---

Bạn muốn mình đi sâu hơn vào phần nào? Ví dụ cách setup SPM workspace thực tế, cách xử lý navigation giữa các module, hay cách áp dụng Tuist?
