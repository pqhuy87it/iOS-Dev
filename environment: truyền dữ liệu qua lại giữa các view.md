// ============================================================
// SWIFTUI .ENVIRONMENT - TRUYỀN DỮ LIỆU QUA LẠI GIỮA CÁC VIEW
// ============================================================
// Environment là cơ chế Dependency Injection (DI) built-in của SwiftUI.
// Dữ liệu được inject ở view cha, TẤT CẢ view con trong subtree
// đều truy cập được — KHÔNG cần truyền qua từng tầng init.
//
// Giải quyết bài toán "Prop Drilling" phổ biến trong UI frameworks.
// ============================================================

import SwiftUI


// ╔══════════════════════════════════════════════════════════╗
// ║  TỔNG QUAN: 4 CƠ CHẾ ENVIRONMENT TRONG SWIFTUI         ║
// ╠══════════════════════════════════════════════════════════╣
// ║                                                          ║
// ║  1. @Environment(\.keyPath)                              ║
// ║     → Đọc system/custom values (colorScheme, locale...)  ║
// ║                                                          ║
// ║  2. @EnvironmentObject + ObservableObject (iOS 13+)      ║
// ║     → Inject reference-type object (LEGACY nhưng phổ biến)║
// ║                                                          ║
// ║  3. @Environment(TypeName.self) + @Observable (iOS 17+)  ║
// ║     → Cách MỚI thay thế @EnvironmentObject              ║
// ║                                                          ║
// ║  4. Custom EnvironmentKey                                ║
// ║     → Tạo key riêng cho value types hoặc closures       ║
// ║                                                          ║
// ╚══════════════════════════════════════════════════════════╝


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 1: @Environment(\.keyPath) — SYSTEM VALUES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// SwiftUI cung cấp sẵn hàng chục environment values.
// View con ĐỌC được mà không cần cha truyền xuống explicitly.

struct SystemEnvironmentDemo: View {
    // --- Đọc system values ---
    @Environment(\.colorScheme) private var colorScheme         // .light / .dark
    @Environment(\.locale) private var locale                   // Locale hiện tại
    @Environment(\.dismiss) private var dismiss                 // Dismiss action
    @Environment(\.openURL) private var openURL                 // Mở URL
    @Environment(\.horizontalSizeClass) private var sizeClass   // .compact / .regular
    @Environment(\.isEnabled) private var isEnabled             // View có enabled không
    @Environment(\.font) private var font                       // Font hiện tại
    @Environment(\.dynamicTypeSize) private var typeSize         // Accessibility text size
    @Environment(\.scenePhase) private var scenePhase           // .active/.inactive/.background
    @Environment(\.modelContext) private var modelContext        // SwiftData context
    @Environment(\.managedObjectContext) private var coreDataCtx // Core Data context
    @Environment(\.calendar) private var calendar
    @Environment(\.timeZone) private var timeZone
    @Environment(\.layoutDirection) private var layoutDirection  // .leftToRight / .rightToLeft
    @Environment(\.redactionReasons) private var redaction       // Placeholder/privacy
    @Environment(\.refresh) private var refresh                 // Pull-to-refresh action
    @Environment(\.editMode) private var editMode               // List edit mode
    
    var body: some View {
        VStack(spacing: 16) {
            // Dùng trực tiếp trong View
            Text(colorScheme == .dark ? "🌙 Dark Mode" : "☀️ Light Mode")
            
            Text("Locale: \(locale.identifier)")
            
            // dismiss() để đóng sheet/navigation
            Button("Đóng") { dismiss() }
            
            // openURL để mở link
            Button("Mở trang web") {
                openURL(URL(string: "https://apple.com")!)
            }
            
            // Responsive layout theo size class
            if sizeClass == .compact {
                Text("iPhone Portrait")
            } else {
                Text("iPad hoặc Landscape")
            }
        }
    }
}

// --- Override system values cho subtree ---
struct OverrideSystemValues: View {
    var body: some View {
        VStack {
            // Tất cả view con trong VStack này sẽ thấy dark mode
            // BẤT KỂ device đang ở light mode
            ChildView()
        }
        .environment(\.colorScheme, .dark)       // Force dark
        .environment(\.locale, Locale(identifier: "vi_VN"))
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.dynamicTypeSize, .large)
    }
}

struct ChildView: View {
    // Nhận giá trị đã bị override → .dark
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        // colorScheme ở đây luôn là .dark
        Text("Theme: \(colorScheme == .dark ? "Dark" : "Light")")
        
        // GrandchildView cũng nhận .dark (cascade xuống toàn subtree)
        GrandchildView()
    }
}

struct GrandchildView: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        // Vẫn là .dark — environment cascade qua MỌI tầng
        Text("Grandchild: \(colorScheme == .dark ? "Dark" : "Light")")
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 2: @EnvironmentObject — LEGACY (iOS 13-16)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Dùng cho reference types conform ObservableObject.
// Vẫn rất phổ biến trong production vì hỗ trợ iOS 13+.
// Nhược điểm: crash runtime nếu quên inject, không type-safe khi compile.

// --- Bước 1: Tạo ObservableObject ---
final class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: String? = nil
    
    func login(username: String) {
        currentUser = username
        isLoggedIn = true
    }
    
    func logout() {
        currentUser = nil
        isLoggedIn = false
    }
}

final class CartManager: ObservableObject {
    @Published var items: [String] = []
    @Published var totalPrice: Double = 0
    
    func addItem(_ item: String, price: Double) {
        items.append(item)
        totalPrice += price
    }
}

// --- Bước 2: Inject ở root view với .environmentObject() ---
struct LegacyApp: View {
    // Tạo instances ở tầng cao nhất
    @StateObject private var authManager = AuthManager()
    @StateObject private var cartManager = CartManager()
    
    var body: some View {
        NavigationStack {
            HomeView()
        }
        // Inject vào environment — cascade xuống toàn bộ subtree
        .environmentObject(authManager)
        .environmentObject(cartManager)
    }
}

// --- Bước 3: Đọc bằng @EnvironmentObject ở BẤT KỲ view con ---
struct HomeView: View {
    // Không cần truyền qua init!
    // SwiftUI tự tìm object theo TYPE trong environment
    @EnvironmentObject var auth: AuthManager
    
    var body: some View {
        VStack {
            if auth.isLoggedIn {
                Text("Xin chào, \(auth.currentUser ?? "")")
                ProductListView()  // không cần pass auth vào init
            } else {
                LoginView()        // không cần pass auth vào init
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager
    
    var body: some View {
        Button("Đăng nhập") {
            auth.login(username: "Huy")
            // @Published thay đổi → TẤT CẢ views dùng auth đều re-render
        }
    }
}

struct ProductListView: View {
    // Có thể dùng NHIỀU EnvironmentObjects cùng lúc
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var cart: CartManager
    
    var body: some View {
        VStack {
            Text("Giỏ hàng: \(cart.items.count) sản phẩm")
            Button("Thêm iPhone") {
                cart.addItem("iPhone", price: 999)
            }
            Button("Đăng xuất") {
                auth.logout()
            }
        }
    }
}

// ⚠️ LƯU Ý QUAN TRỌNG @EnvironmentObject:
//
// 1. CRASH nếu quên inject:
//    NavigationStack { HomeView() }
//    // THIẾU .environmentObject(authManager) → crash runtime!
//    // Lỗi: "No ObservableObject of type AuthManager found"
//
// 2. Lookup theo TYPE, không theo instance name:
//    .environmentObject(authManagerA)
//    .environmentObject(authManagerB) // ← Override! Chỉ giữ B
//    // Vì cả hai cùng type AuthManager → instance sau ghi đè
//
// 3. Mỗi type chỉ có 1 instance trong environment tree
//    → Nếu cần nhiều instances cùng type, dùng Custom EnvironmentKey (Phần 4)
//
// 4. @EnvironmentObject trigger re-render khi BẤT KỲ @Published nào thay đổi
//    → Có thể gây unnecessary renders nếu object có nhiều properties


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 3: @Observable + @Environment (iOS 17+) — CÁCH MỚI
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Apple khuyến khích dùng @Observable thay ObservableObject từ iOS 17+.
// Ưu điểm:
// - Fine-grained observation: chỉ re-render khi property ĐANG DÙNG thay đổi
// - Compile-time safety: lỗi type nếu quên inject
// - Syntax đơn giản hơn, không cần @Published

@Observable  // Thay thế ObservableObject + @Published
final class UserSession {
    var isLoggedIn: Bool = false
    var username: String = ""
    var avatarURL: URL? = nil
    
    // Không cần @Published — @Observable tự track tất cả stored properties
    // Dùng @ObservationIgnored nếu KHÔNG muốn track
    @ObservationIgnored
    var internalCache: [String: Any] = [:]
    
    func login(name: String) {
        username = name
        isLoggedIn = true
    }
    
    func logout() {
        username = ""
        isLoggedIn = false
        avatarURL = nil
    }
}

@Observable
final class ThemeManager {
    var primaryColor: Color = .blue
    var fontSize: CGFloat = 16
    var isDarkMode: Bool = false
}

// --- Inject: dùng .environment(object) thay vì .environmentObject ---
struct ModernApp: View {
    // @State thay vì @StateObject cho @Observable
    @State private var session = UserSession()
    @State private var theme = ThemeManager()
    
    var body: some View {
        NavigationStack {
            ModernHomeView()
        }
        // Cú pháp MỚI: .environment(instance)
        // Truyền vào trực tiếp, SwiftUI tự detect type
        .environment(session)
        .environment(theme)
    }
}

// --- Đọc: @Environment(TypeName.self) ---
struct ModernHomeView: View {
    // Cú pháp MỚI: truyền TYPE.self thay vì keyPath
    @Environment(UserSession.self) private var session
    @Environment(ThemeManager.self) private var theme
    
    var body: some View {
        VStack(spacing: 20) {
            // Fine-grained: View này CHỈ re-render khi
            // session.isLoggedIn hoặc session.username thay đổi
            // KHÔNG re-render khi session.avatarURL thay đổi
            // (vì avatarURL không được đọc ở đây)
            Text(session.isLoggedIn ? "Chào \(session.username)" : "Chưa đăng nhập")
                .font(.system(size: theme.fontSize))
                .foregroundColor(theme.primaryColor)
            
            ModernLoginButton()
            ModernProfileView()
        }
    }
}

struct ModernLoginButton: View {
    @Environment(UserSession.self) private var session
    
    var body: some View {
        Button(session.isLoggedIn ? "Đăng xuất" : "Đăng nhập") {
            if session.isLoggedIn {
                session.logout()
            } else {
                session.login(name: "Huy")
            }
        }
    }
}

struct ModernProfileView: View {
    @Environment(UserSession.self) private var session
    
    var body: some View {
        // View này CHỈ re-render khi username hoặc avatarURL thay đổi
        // KHÔNG re-render khi isLoggedIn thay đổi
        // → Performance tốt hơn @EnvironmentObject rất nhiều!
        VStack {
            Text("Profile: \(session.username)")
            if let url = session.avatarURL {
                AsyncImage(url: url)
            }
        }
    }
}

// --- @Bindable + @Environment: Two-way binding ---
struct ModernSettingsView: View {
    @Environment(ThemeManager.self) private var theme
    
    var body: some View {
        // Cần @Bindable để tạo Binding từ @Observable object
        @Bindable var theme = theme
        
        Form {
            // Two-way binding: thay đổi ở đây → update mọi nơi dùng theme
            ColorPicker("Màu chính", selection: $theme.primaryColor)
            
            Slider(value: $theme.fontSize, in: 12...32) {
                Text("Cỡ chữ: \(Int(theme.fontSize))")
            }
            
            Toggle("Dark Mode", isOn: $theme.isDarkMode)
        }
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 4: CUSTOM EnvironmentKey — TẠO KEY RIÊNG
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Dùng khi:
// - Truyền value types (String, Int, Bool, enum...)
// - Truyền closures / callbacks
// - Cần nhiều instances cùng type
// - Tạo API giống system environment (.font, .tint...)

// === 4a. Value Type ===

// Bước 1: Định nghĩa EnvironmentKey
private struct AppThemeColorKey: EnvironmentKey {
    // defaultValue BẮT BUỘC — dùng khi không ai inject
    static let defaultValue: Color = .blue
}

// Bước 2: Extend EnvironmentValues
extension EnvironmentValues {
    var appThemeColor: Color {
        get { self[AppThemeColorKey.self] }
        set { self[AppThemeColorKey.self] = newValue }
    }
}

// Bước 3 (Optional): Tạo View modifier cho syntax đẹp
extension View {
    func appThemeColor(_ color: Color) -> some View {
        environment(\.appThemeColor, color)
    }
}

// Sử dụng:
struct CustomKeyDemo: View {
    var body: some View {
        VStack {
            ScreenA()
            ScreenB()
        }
        // Cách 1: dùng .environment trực tiếp
        .environment(\.appThemeColor, .purple)
        // Cách 2: dùng custom modifier (syntax đẹp hơn)
        // .appThemeColor(.purple)
    }
}

struct ScreenA: View {
    @Environment(\.appThemeColor) private var themeColor
    var body: some View {
        Text("Screen A")
            .foregroundStyle(themeColor) // → purple
    }
}

struct ScreenB: View {
    @Environment(\.appThemeColor) private var themeColor
    var body: some View {
        // Override cho subtree riêng
        VStack {
            Text("Screen B Header")
                .foregroundStyle(themeColor) // → green (overridden)
            ScreenBChild()
        }
        .environment(\.appThemeColor, .green)
    }
}

struct ScreenBChild: View {
    @Environment(\.appThemeColor) private var themeColor
    var body: some View {
        Text("Screen B Child")
            .foregroundStyle(themeColor) // → green (inherited từ ScreenB)
    }
}


// === 4b. Closure / Action ===
// Pattern cực kỳ hữu ích: inject hành vi (behavior) thay vì data

private struct ShowAlertActionKey: EnvironmentKey {
    // Default là closure rỗng
    static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
    var showAlert: (String) -> Void {
        get { self[ShowAlertActionKey.self] }
        set { self[ShowAlertActionKey.self] = newValue }
    }
}

struct AlertDemo: View {
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    var body: some View {
        DeepNestedView()
            .environment(\.showAlert, { message in
                // View con gọi → cha xử lý
                alertMessage = message
                showingAlert = true
            })
            .alert(alertMessage, isPresented: $showingAlert) {
                Button("OK") {}
            }
    }
}

struct DeepNestedView: View {
    @Environment(\.showAlert) private var showAlert
    
    var body: some View {
        Button("Báo lỗi") {
            // Gọi closure được inject từ cha
            // Không cần biết cha xử lý như thế nào (decoupled!)
            showAlert("Đã xảy ra lỗi mạng!")
        }
    }
}


// === 4c. Optional Type ===
private struct CurrentUserKey: EnvironmentKey {
    static let defaultValue: String? = nil  // Optional default
}

extension EnvironmentValues {
    var currentUser: String? {
        get { self[CurrentUserKey.self] }
        set { self[CurrentUserKey.self] = newValue }
    }
}


// === 4d. Enum / Config ===
enum AppEnvironment: String {
    case development, staging, production
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .production
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// Inject theo build config:
struct ConfigurableApp: View {
    var body: some View {
        ContentView()
            #if DEBUG
            .environment(\.appEnvironment, .development)
            #else
            .environment(\.appEnvironment, .production)
            #endif
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 5: SO SÁNH @EnvironmentObject vs @Environment(@Observable)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ┌──────────────────────┬──────────────────────┬──────────────────────┐
// │     Tiêu chí         │  @EnvironmentObject  │  @Environment +      │
// │                      │  (iOS 13+)           │  @Observable (17+)   │
// ├──────────────────────┼──────────────────────┼──────────────────────┤
// │ Object protocol      │ ObservableObject     │ @Observable macro    │
// │ Property tracking    │ @Published           │ Tự động (all stored) │
// │ Inject modifier      │ .environmentObject() │ .environment()       │
// │ Read wrapper         │ @EnvironmentObject   │ @Environment(T.self) │
// │ Owner wrapper        │ @StateObject         │ @State               │
// │ Re-render scope      │ ANY @Published change│ Chỉ properties ĐANG  │
// │                      │ → re-render ALL views│ ĐỌC thay đổi        │
// │ Missing injection    │ CRASH runtime ❌     │ Compile warning ⚠️   │
// │ Two-way binding      │ Trực tiếp $ syntax   │ Cần @Bindable        │
// │ Min deployment       │ iOS 13               │ iOS 17               │
// └──────────────────────┴──────────────────────┴──────────────────────┘

// VÍ DỤ RE-RENDER DIFFERENCE:
// ObservableObject: CartManager có items + totalPrice + couponCode
// View chỉ hiển thị totalPrice
// → Khi items thay đổi: RE-RENDER (dù view không dùng items) ❌
//
// @Observable: Cùng CartManager
// View chỉ hiển thị totalPrice
// → Khi items thay đổi: KHÔNG re-render ✅ (fine-grained tracking)


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 6: ENVIRONMENT PROPAGATION RULES (QUY TẮC LAN TRUYỀN)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// 1. CASCADE: Environment values đi XUỐNG toàn bộ view subtree
//
//    Root
//    ├── .environment(\.colorScheme, .dark)
//    │   ├── ViewA → thấy .dark ✅
//    │   │   └── ViewB → thấy .dark ✅ (inherited)
//    │   └── ViewC → thấy .dark ✅
//    └── ViewD → thấy system default (không trong subtree)

// 2. OVERRIDE: View con có thể override cho subtree của nó
//
//    Root
//    ├── .environment(\.colorScheme, .dark)
//    │   ├── ViewA → .dark
//    │   │   ├── .environment(\.colorScheme, .light) ← OVERRIDE
//    │   │   │   └── ViewB → .light ✅ (nearest ancestor wins)
//    │   │   └── ViewC → .dark (không bị ảnh hưởng bởi override)
//    │   └── ViewD → .dark

// 3. SHEET / FULLSCREENCOVER: TẠO ENVIRONMENT MỚI!
//    ⚠️ Đây là bug/gotcha phổ biến nhất

struct SheetEnvironmentIssue: View {
    @State private var session = UserSession()
    @State private var showSheet = false
    
    var body: some View {
        Button("Show Sheet") { showSheet = true }
            .environment(session)
            .sheet(isPresented: $showSheet) {
                // ⚠️ Sheet tạo window MỚI → environment KHÔNG tự cascade!
                // Phải inject LẠI:
                SheetContentView()
                    .environment(session) // ← BẮT BUỘC phải inject lại!
            }
        
        // Tương tự cho:
        // .fullScreenCover { ... .environment(session) }
        // .popover { ... .environment(session) }
    }
}

struct SheetContentView: View {
    @Environment(UserSession.self) private var session
    var body: some View {
        Text("Sheet: \(session.username)")
    }
}

// 4. NAVIGATIONDESTINATION: KẾ THỪA environment ✅
//    NavigationStack tự động propagate environment cho destinations
struct NavEnvironmentDemo: View {
    @State private var session = UserSession()
    
    var body: some View {
        NavigationStack {
            NavigationLink("Go to Detail", value: "detail")
                .navigationDestination(for: String.self) { _ in
                    DetailView() // ← Tự nhận session từ environment ✅
                }
        }
        .environment(session) // Chỉ cần inject 1 lần
    }
}

struct DetailView: View {
    @Environment(UserSession.self) private var session
    var body: some View {
        Text("Detail: \(session.username)") // Hoạt động bình thường ✅
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 7: PRODUCTION PATTERNS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// === 7a. Dependency Injection Container ===
// Gom tất cả dependencies vào 1 chỗ

@Observable
final class AppDependencies {
    let authService: AuthServiceProtocol
    let networkService: NetworkServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    
    init(
        auth: AuthServiceProtocol = AuthService(),
        network: NetworkServiceProtocol = NetworkService(),
        analytics: AnalyticsServiceProtocol = AnalyticsService()
    ) {
        self.authService = auth
        self.networkService = network
        self.analyticsService = analytics
    }
}

// Protocols cho testability
protocol AuthServiceProtocol { func login() async throws }
protocol NetworkServiceProtocol { func fetch(_ url: URL) async throws -> Data }
protocol AnalyticsServiceProtocol { func track(_ event: String) }

// Implementations
struct AuthService: AuthServiceProtocol { func login() async throws {} }
struct NetworkService: NetworkServiceProtocol { func fetch(_ url: URL) async throws -> Data { Data() } }
struct AnalyticsService: AnalyticsServiceProtocol { func track(_ event: String) {} }

struct DIApp: View {
    @State private var deps = AppDependencies()
    
    var body: some View {
        RootView()
            .environment(deps)
    }
}

// === 7b. Environment cho Router / Coordinator ===

@Observable
final class Router {
    var path = NavigationPath()
    
    enum Destination: Hashable {
        case taskDetail(id: String)
        case settings
        case profile(username: String)
    }
    
    func navigate(to dest: Destination) {
        path.append(dest)
    }
    
    func goBack() {
        path.removeLast()
    }
    
    func goToRoot() {
        path.removeLast(path.count)
    }
}

struct RouterApp: View {
    @State private var router = Router()
    
    var body: some View {
        NavigationStack(path: $router.path) {
            HomeScreen()
                .navigationDestination(for: Router.Destination.self) { dest in
                    switch dest {
                    case .taskDetail(let id):
                        Text("Task: \(id)")
                    case .settings:
                        Text("Settings")
                    case .profile(let username):
                        Text("Profile: \(username)")
                    }
                }
        }
        .environment(router)
    }
}

struct HomeScreen: View {
    @Environment(Router.self) private var router
    
    var body: some View {
        VStack {
            Button("Mở Settings") {
                router.navigate(to: .settings)
            }
            Button("Xem Profile") {
                router.navigate(to: .profile(username: "Huy"))
            }
        }
    }
}


// === 7c. Environment cho Feature Flags ===

@Observable
final class FeatureFlags {
    var isNewUIEnabled: Bool = false
    var isPaymentV2Enabled: Bool = false
    var maxUploadSizeMB: Int = 50
    
    func loadFromRemoteConfig() async {
        // Fetch từ Firebase Remote Config, LaunchDarkly, etc.
    }
}

struct FeatureFlaggedView: View {
    @Environment(FeatureFlags.self) private var flags
    
    var body: some View {
        if flags.isNewUIEnabled {
            NewDashboardView()
        } else {
            LegacyDashboardView()
        }
    }
}

struct NewDashboardView: View { var body: some View { Text("New UI") } }
struct LegacyDashboardView: View { var body: some View { Text("Legacy UI") } }


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 8: TESTING VỚI ENVIRONMENT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Environment giúp swap dependencies cực dễ khi test

// --- Mock cho Unit Test ---
struct MockAuthService: AuthServiceProtocol {
    func login() async throws {}
}

struct MockNetworkService: NetworkServiceProtocol {
    var mockData: Data = Data()
    func fetch(_ url: URL) async throws -> Data { mockData }
}

struct MockAnalyticsService: AnalyticsServiceProtocol {
    var trackedEvents: [String] = []
    mutating func track(_ event: String) { trackedEvents.append(event) }
}

// --- Preview với mock data ---
#Preview("Logged In State") {
    let session = UserSession()
    session.isLoggedIn = true
    session.username = "Huy Preview"
    
    return ModernHomeView()
        .environment(session)
        .environment(ThemeManager())
}

#Preview("Logged Out State") {
    ModernHomeView()
        .environment(UserSession())
        .environment(ThemeManager())
}

#Preview("Dark Theme") {
    ModernHomeView()
        .environment(UserSession())
        .environment(ThemeManager())
        .environment(\.colorScheme, .dark)
}

// --- XCUITest: inject test config ---
// Trong App init, check launch arguments:
// if ProcessInfo.processInfo.arguments.contains("--uitesting") {
//     let mockDeps = AppDependencies(
//         auth: MockAuthService(),
//         network: MockNetworkService(),
//         analytics: MockAnalyticsService()
//     )
//     return deps = mockDeps
// }


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 9: ANTI-PATTERNS & BEST PRACTICES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// ❌ ANTI-PATTERN 1: God Object
// Đừng nhét tất cả vào 1 environment object khổng lồ
// @Observable final class AppState {
//     var user, cart, settings, theme, notifications, orders... // QUÁ NHIỀU
// }
// → Re-render waterfall, khó test, khó maintain

// ✅ FIX: Tách nhỏ theo domain
// UserSession, CartManager, ThemeManager, NotificationManager...


// ❌ ANTI-PATTERN 2: Quên inject cho Sheet
// .sheet { SheetView() } // CRASH hoặc dùng default value sai


// ❌ ANTI-PATTERN 3: Dùng Environment cho data chỉ 1-2 tầng
// Nếu chỉ truyền Parent → Child, dùng init parameter đơn giản hơn
// Environment phù hợp khi data cần đi qua NHIỀU tầng

// ❌ ANTI-PATTERN 4: Business logic trong View
// struct MyView: View {
//     @Environment(UserSession.self) var session
//     func calculateDiscount() { ... } // ❌ Logic ở đây
// }

// ✅ FIX: Tách ViewModel hoặc Service
// ViewModel nhận dependency qua init, View inject từ environment


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PHẦN 10: DECISION TREE — CHỌN CƠ CHẾ NÀO?
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Cần truyền data xuống view con?
// │
// ├── Chỉ 1-2 tầng? → init parameter (đơn giản nhất)
// │
// ├── Nhiều tầng (3+)?
// │   │
// │   ├── Reference type (class) cần shared state?
// │   │   ├── iOS 17+? → @Observable + .environment()     ← KHUYẾN KHÍCH
// │   │   └── iOS 13+? → ObservableObject + .environmentObject()
// │   │
// │   ├── Value type (String, Int, enum, struct)?
// │   │   └── Custom EnvironmentKey
// │   │
// │   └── Closure / Action callback?
// │       └── Custom EnvironmentKey với closure type
// │
// └── System value (colorScheme, locale...)?
//     └── @Environment(\.keyPath) — đã có sẵn

---

Đây là một chủ đề nền tảng của SwiftUI, và cũng là nơi Apple thay đổi khá nhiều qua các phiên bản. Mình sẽ giải thích toàn bộ hệ thống Environment từ gốc đến ngọn.Mình đã tổng hợp toàn bộ hệ thống Environment trong 10 phần. Đây là những điểm cốt lõi cần nắm:

**Bản chất của Environment** là cơ chế Dependency Injection built-in, giải quyết bài toán "prop drilling" — thay vì truyền data qua init từng tầng, bạn inject ở cha và tất cả con cháu trong subtree đều truy cập được.

**Thay đổi quan trọng nhất ở iOS 17** là `@Observable` macro thay thế `ObservableObject`. Sự khác biệt then chốt nằm ở **fine-grained observation**: với `@EnvironmentObject` cũ, khi bất kỳ `@Published` nào thay đổi thì tất cả views đang subscribe đều re-render. Với `@Observable` mới, SwiftUI chỉ re-render view nào đang **thực sự đọc** property bị thay đổi — performance improvement rất lớn trong ứng dụng phức tạp.

**Gotcha phổ biến nhất** mà mình highlight đặc biệt ở **Phần 6**: Sheet, FullScreenCover và Popover tạo window mới nên **không tự kế thừa environment** — phải inject lại. Đây là nguyên nhân crash mà rất nhiều developer gặp phải.

**Pattern hữu ích nhất cho production** ở **Phần 7**: Custom EnvironmentKey với closure type cho phép inject *hành vi* (behavior injection) thay vì chỉ data. Ví dụ `showAlert` closure — view con gọi mà không cần biết cha xử lý ra sao, hoàn toàn decoupled. Pattern này kết hợp tốt với Router/Coordinator và Feature Flags.

**Decision tree ở Phần 10** tóm gọn cách chọn: chỉ 1-2 tầng → dùng init parameter; nhiều tầng + reference type → `@Observable` (iOS 17+) hoặc `ObservableObject` (iOS 13+); value type hoặc closure → Custom EnvironmentKey.

Huy muốn mình đi sâu hơn vào phần nào — ví dụ pattern kết hợp Environment với MVVM-C (Coordinator), hoặc cách optimize performance khi có nhiều environment objects?
