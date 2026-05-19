# "Solid Understanding of Mobile Application Architecture" — Dành cho Senior iOS Developer

Đây là một trong những yêu cầu cốt lõi nhất đối với một Senior iOS Developer. Nó không chỉ đơn giản là "biết code", mà là khả năng **thiết kế, tổ chức và đưa ra quyết định kỹ thuật** cho toàn bộ ứng dụng. Mình sẽ tách ra từng khía cạnh:

---

## 1. Các Architecture Patterns phổ biến trên iOS

Một senior cần hiểu sâu và biết khi nào nên dùng pattern nào:

**MVC (Model-View-Controller)** — Pattern mặc định của Apple. Đơn giản nhưng dễ dẫn đến "Massive View Controller" khi ứng dụng phình to. Senior cần biết cách tách logic ra khỏi ViewController để tránh điều này.

**MVVM (Model-View-ViewModel)** — Tách business logic ra ViewModel, giúp ViewController "gầy" hơn và dễ viết unit test. Kết hợp rất tốt với Combine hoặc RxSwift thông qua data binding.

**VIPER (View-Interactor-Presenter-Entity-Router)** — Chia nhỏ trách nhiệm rất rõ ràng, phù hợp với team lớn và dự án phức tạp. Tuy nhiên đi kèm nhiều boilerplate code.

**Clean Architecture / TCA (The Composable Architecture)** — Clean Architecture tách ứng dụng thành các layer (Domain, Data, Presentation) với dependency rule hướng vào trong. TCA của Point-Free thì quản lý state theo kiểu unidirectional, rất phù hợp với SwiftUI.

Senior không chỉ "biết" các pattern này mà phải **đánh giá trade-off** để chọn pattern phù hợp với quy mô team, độ phức tạp của dự án và khả năng maintain lâu dài.

---

## 2. App Structure & Module Organization

**Modularization** — Tách ứng dụng thành các module độc lập (Feature modules, Core module, Networking module, UI Kit module...) bằng Swift Package Manager hoặc framework riêng. Điều này giúp giảm build time, tăng khả năng reuse và cho phép nhiều team làm song song.

**Dependency Injection** — Thay vì các class tự tạo dependency, chúng được "inject" từ bên ngoài vào. Điều này giúp code dễ test và linh hoạt hơn. Senior cần hiểu các cách triển khai: constructor injection, property injection, hoặc dùng container như Swinject.

**Coordinator / Router Pattern** — Tách navigation logic ra khỏi ViewController. Thay vì ViewController A phải "biết" ViewController B để push, một Coordinator sẽ quản lý toàn bộ flow điều hướng. Điều này giúp các màn hình độc lập và dễ tái sử dụng hơn.

---

## 3. Data Flow & State Management

Senior cần trả lời được: **"Dữ liệu đi từ đâu, qua đâu, và hiển thị như thế nào?"**

**Unidirectional Data Flow** — Dữ liệu chỉ chảy một chiều (ví dụ: User Action → State Change → UI Update). Giúp dễ debug và dự đoán hành vi ứng dụng. SwiftUI với `@State`, `@ObservedObject`, `@EnvironmentObject` được thiết kế theo hướng này.

**Reactive Programming** — Dùng Combine (native) hoặc RxSwift để xử lý luồng dữ liệu bất đồng bộ, giúp code gọn gàng hơn so với callback/delegate truyền thống.

**Source of Truth** — Luôn phải xác định rõ đâu là nguồn dữ liệu "đáng tin cậy" duy nhất cho mỗi phần dữ liệu, tránh tình trạng state bị phân mảnh và không đồng bộ giữa các nơi.

---

## 4. Networking & Data Layer

**Repository Pattern** — Tạo một lớp trung gian giữa business logic và data source. ViewModel chỉ gọi repository, không cần biết dữ liệu đến từ API, cache hay database. Khi cần đổi data source, chỉ sửa repository mà không ảnh hưởng phần còn lại.

**Offline-first Strategy** — Thiết kế để app hoạt động tốt cả khi mất mạng: dùng Core Data hoặc Swift Data làm local cache, sync khi có mạng trở lại, xử lý conflict resolution.

**API Layer Abstraction** — Đóng gói networking (URLSession, Alamofire...) sau một protocol/interface, giúp dễ mock khi test và dễ thay thế thư viện sau này.

---

## 5. Persistence Layer

Senior cần biết khi nào dùng công cụ nào:

- **UserDefaults** — Cho dữ liệu nhỏ, đơn giản (settings, flags).
- **Keychain** — Cho dữ liệu nhạy cảm (token, password).
- **Core Data / SwiftData** — Cho dữ liệu phức tạp, có quan hệ, cần query.
- **File System** — Cho file lớn (ảnh, video, document).
- **SQLite trực tiếp (GRDB, FMDB)** — Khi cần kiểm soát tối đa hiệu năng truy vấn.

---

## 6. Concurrency & Performance

**Swift Concurrency (async/await, Actor)** — Hiểu cách dùng `Task`, `TaskGroup`, `@MainActor`, `actor` để viết code bất đồng bộ an toàn, tránh data race.

**Memory Management** — Hiểu rõ ARC, retain cycle, khi nào dùng `weak`/`unowned`. Biết dùng Instruments (Leaks, Allocations) để phát hiện memory leak.

**Performance Optimization** — Lazy loading, image caching, tối ưu `UITableView`/`UICollectionView` (cell reuse, prefetching), tránh main thread blocking.

---

## 7. Testability & Scalability

Một kiến trúc tốt phải **dễ test**. Senior cần thiết kế sao cho mỗi layer có thể test độc lập: ViewModel test business logic mà không cần UI, Repository test mà không cần gọi API thật (dùng mock). Điều này chỉ đạt được khi các layer được tách rõ ràng và giao tiếp qua protocol.

Về scalability, kiến trúc phải cho phép thêm feature mới mà không cần refactor lớn, onboard thành viên mới dễ dàng, và nhiều team có thể làm việc song song trên cùng codebase.

---

## Tóm lại

"Solid understanding of mobile application architecture" với một Senior iOS Developer nghĩa là bạn có khả năng **nhìn ứng dụng như một hệ thống**, hiểu cách các thành phần kết nối và ảnh hưởng lẫn nhau, và đưa ra quyết định thiết kế có cân nhắc trade-off rõ ràng — không phải chỉ "code chạy được" mà là "code chạy tốt, dễ maintain, dễ test, và dễ mở rộng trong dài hạn".

Bạn muốn mình đi sâu hơn vào phần nào không?

# 1.Modularization trong iOS

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
