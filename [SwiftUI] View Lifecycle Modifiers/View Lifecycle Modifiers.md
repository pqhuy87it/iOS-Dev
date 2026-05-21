```Swift
// ============================================================
// VIEW LIFECYCLE MODIFIERS TRONG SWIFTUI — GIẢI THÍCH CHI TIẾT
// ============================================================
// SwiftUI KHÔNG có viewDidLoad, viewWillAppear... như UIKit.
// Thay vào đó, hệ thống lifecycle KHAI BÁO (declarative) qua
// các modifiers gắn trên View.
//
// TOÀN BỘ lifecycle modifiers:
//
// ┌─ APPEARANCE ──────────────────────────────────┐
// │  .onAppear { }              iOS 13+           │
// │  .onDisappear { }           iOS 13+           │
// ├─ ASYNC WORK ──────────────────────────────────┤
// │  .task { }                  iOS 15+           │
// │  .task(id:) { }             iOS 15+           │
// ├─ VALUE OBSERVATION ───────────────────────────┤
// │  .onChange(of:) { }         iOS 14+ / 17+ API │
// ├─ GEOMETRY ────────────────────────────────────┤
// │  .onGeometryChange()        iOS 18+           │
// ├─ SCENE PHASE ─────────────────────────────────┤
// │  @Environment(\.scenePhase)                   │
// │  .onChange(of: scenePhase)                     │
// ├─ USER INTERACTION ────────────────────────────┤
// │  .onSubmit { }              iOS 15+           │
// │  .onTapGesture { }         iOS 13+           │
// │  .onLongPressGesture { }   iOS 13+           │
// ├─ SCROLL ──────────────────────────────────────┤
// │  .onScrollVisibilityChange  iOS 18+           │
// │  .onScrollGeometryChange    iOS 18+           │
// │  .scrollPosition(id:)       iOS 17+           │
// ├─ DATA / URL ──────────────────────────────────┤
// │  .onOpenURL { }             iOS 14+           │
// │  .onContinueUserActivity    iOS 14+           │
// │  .refreshable { }           iOS 15+           │
// ├─ KEYBOARD ────────────────────────────────────┤
// │  .onKeyPress { }            iOS 17+           │
// └───────────────────────────────────────────────┘
// ============================================================

import SwiftUI


// ╔══════════════════════════════════════════════════════════╗
// ║  1. THỨ TỰ LIFECYCLE — BỨC TRANH TOÀN CẢNH              ║
// ╚══════════════════════════════════════════════════════════╝

// Khi một view XUẤT HIỆN trên màn hình, các events fire theo thứ tự:
//
// ┌──────────────────────────────────────────────────────┐
// │                  VIEW APPEAR SEQUENCE                 │
// │                                                      │
// │  1. View struct init() — body computed               │
// │  2. @State, @StateObject initialized (lần đầu)      │
// │  3. SwiftUI diff & build render tree                 │
// │  4. ▶ .onAppear { }         ← Sync setup            │
// │  5. ▶ .task { }             ← Async work starts     │
// │  6. View renders on screen                           │
// │  7. ▶ .task(id:) evaluates initial id                │
// │                                                      │
// │                USER INTERACTING...                    │
// │                                                      │
// │  8. State changes → body recomputed                  │
// │  9. ▶ .onChange(of:) { }    ← Value changed          │
// │  10. ▶ .task(id:) restarts if id changed             │
// │                                                      │
// │                VIEW ABOUT TO LEAVE...                 │
// │                                                      │
// │  11. ▶ .task { } CANCELLED  ← Auto-cancel            │
// │  12. ▶ .onDisappear { }     ← Cleanup                │
// │  13. View removed from render tree                    │
// └──────────────────────────────────────────────────────┘

struct LifecycleSequenceDemo: View {
    @State private var log: [String] = []
    @State private var counter = 0
    
    var body: some View {
        let _ = logEvent("body computed (render #\(counter))")
        
        VStack(spacing: 12) {
            Text("Lifecycle Log")
                .font(.headline)
            
            Button("Change State") { counter += 1 }
                .buttonStyle(.bordered)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        // Lifecycle modifiers — observe firing order:
        .onAppear {
            logEvent("⚡ .onAppear")
        }
        .task {
            logEvent("⚡ .task started")
            // Simulate async work
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled {
                logEvent("⚡ .task completed")
            } else {
                logEvent("⚡ .task CANCELLED")
            }
        }
        .onChange(of: counter) { old, new in
            logEvent("⚡ .onChange: \(old) → \(new)")
        }
        .onDisappear {
            logEvent("⚡ .onDisappear")
        }
    }
    
    func logEvent(_ event: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        let entry = "[\(f.string(from: .now))] \(event)"
        log.append(entry)
        print(entry)
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  2. .onAppear & .onDisappear — APPEAR/DISAPPEAR          ║
// ╚══════════════════════════════════════════════════════════╝

// .onAppear:  view SẮP HIỂN THỊ (before visible)
// .onDisappear: view SẮP BIẾN MẤT (before removal)
// Cả hai: SYNCHRONOUS, chạy trên Main Thread.

// === Khi nào fire / không fire ===
// ┌──────────────────────────┬───────────┬──────────────┐
// │ Tình huống               │ onAppear  │ onDisappear  │
// ├──────────────────────────┼───────────┼──────────────┤
// │ Lần đầu render           │ ✅        │              │
// │ Tab switch (đi → về)     │ ✅ Lại    │ ✅           │
// │ Navigation push          │ ✅ Child  │              │
// │ Navigation pop back      │ ✅ Parent │ ✅ Child     │
// │ Sheet present            │ ✅ Sheet  │ ❌ Parent    │
// │ Sheet dismiss            │ ❌ Parent │ ✅ Sheet     │
// │ LazyVStack scroll in/out │ ✅ / ✅   │ ✅ / ✅      │
// │ if/else toggle on        │ ✅ Mới    │              │
// │ if/else toggle off       │           │ ✅ Destroy   │
// │ Background → Foreground  │ ❌        │ ❌           │
// │ @State change (re-render)│ ❌        │ ❌           │
// │ .id() thay đổi           │ ✅ Mới    │ ✅ Cũ       │
// └──────────────────────────┴───────────┴──────────────┘

struct AppearDisappearDemo: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Appear count: \(count)")
            
            // ⚠️ CÓ THỂ fire NHIỀU LẦN
            // Guard nếu chỉ muốn chạy 1 lần
        }
        .onAppear {
            count += 1
            // Setup: animation trigger, analytics, observer registration
        }
        .onDisappear {
            // Cleanup: invalidate timer, remove observer, cancel work
        }
    }
}

// === Dùng cho gì? ===
// .onAppear:
//   ✅ Trigger entrance animation
//   ✅ Analytics screen tracking
//   ✅ Start timer / register observer
//   ✅ One-time sync setup (với guard)
//   ❌ KHÔNG dùng cho async work → dùng .task
//   ❌ KHÔNG dùng cho heavy computation → block main thread
//
// .onDisappear:
//   ✅ Stop timer / remove observer
//   ✅ Analytics screen exit tracking
//   ✅ Save intermediate state
//   ✅ Cancel manual operations (nếu không dùng .task)


// ╔══════════════════════════════════════════════════════════╗
// ║  3. .task & .task(id:) — ASYNC LIFECYCLE                  ║
// ╚══════════════════════════════════════════════════════════╝

// .task: async version của .onAppear — nhưng MẠNH HƠN:
// - async/await native
// - TỰ ĐỘNG CANCEL khi view disappear
// - .task(id:) tự restart khi id thay đổi

// === 3a. .task — Basic async work ===

struct TaskBasicDemo: View {
    @State private var data: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        List(data, id: \.self) { Text($0) }
            .overlay { if isLoading { ProgressView() } }
            .task {
                // ✅ Async context — await trực tiếp
                isLoading = true
                defer { isLoading = false }
                
                // ✅ Nếu view disappear → Task TỰ CANCEL
                // → sleep throws CancellationError → function exit
                try? await Task.sleep(for: .seconds(1))
                
                // ✅ Nên check cancellation sau mỗi await point
                guard !Task.isCancelled else { return }
                
                data = await fetchFromAPI()
            }
    }
    
    func fetchFromAPI() async -> [String] {
        (1...20).map { "Item \($0)" }
    }
}

// === 3b. .task(id:) — Restart khi dependency thay đổi ===

struct TaskIDDemo: View {
    @State private var category = "all"
    @State private var items: [String] = []
    
    let categories = ["all", "tech", "design"]
    
    var body: some View {
        VStack {
            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            
            List(items, id: \.self) { Text($0) }
        }
        .task(id: category) {
            // FLOW khi category thay đổi:
            // 1. Task CŨ bị CANCEL (đang fetch "all" → cancel)
            // 2. Task MỚI bắt đầu (fetch "tech")
            // → KHÔNG CÓ race condition!
            
            items = [] // Clear old data
            try? await Task.sleep(for: .milliseconds(500))
            
            guard !Task.isCancelled else { return }
            items = (1...10).map { "\(category) item \($0)" }
        }
    }
}

// === 3c. .task(id:) thay thế .onAppear + .onChange ===

// ❌ CŨ: 2 modifiers, không auto-cancel
struct OldPattern: View {
    @State private var query = ""
    @State private var results: [String] = []
    
    var body: some View {
        List(results, id: \.self) { Text($0) }
            .onAppear { search() }
            .onChange(of: query) { _, _ in search() }
        // Vấn đề: search() là sync, nếu async thì phải
        // quản lý Task thủ công + cancel logic
    }
    
    func search() {
        results = ["Result for \(query)"]
    }
}

// ✅ MỚI: 1 modifier, auto-cancel, async native
struct NewPattern: View {
    @State private var query = ""
    @State private var results: [String] = []
    
    var body: some View {
        List(results, id: \.self) { Text($0) }
            .task(id: query) {
                // Fire khi: appear + query thay đổi
                // Auto-cancel task cũ khi query đổi
                try? await Task.sleep(for: .milliseconds(300)) // debounce
                guard !Task.isCancelled else { return }
                results = await searchAPI(query)
            }
    }
    
    func searchAPI(_ q: String) async -> [String] {
        (1...5).map { "Result \($0) for '\(q)'" }
    }
}

// === 3d. Multiple .task trên cùng view ===

struct MultipleTaskDemo: View {
    @State private var user: String?
    @State private var posts: [String] = []
    @State private var notifications = 0
    
    var body: some View {
        VStack {
            Text("User: \(user ?? "loading...")")
            Text("Posts: \(posts.count)")
            Text("Notifications: \(notifications)")
        }
        // ✅ Nhiều .task CHẠY SONG SONG (concurrent)
        .task {
            user = await fetchUser()
        }
        .task {
            posts = await fetchPosts()
        }
        .task {
            notifications = await fetchNotificationCount()
        }
        // Tất cả 3 tasks start cùng lúc khi view appear
        // Tất cả auto-cancel khi view disappear
    }
    
    func fetchUser() async -> String {
        try? await Task.sleep(for: .seconds(1))
        return "Huy"
    }
    func fetchPosts() async -> [String] {
        try? await Task.sleep(for: .seconds(1.5))
        return (1...10).map { "Post \($0)" }
    }
    func fetchNotificationCount() async -> Int {
        try? await Task.sleep(for: .seconds(0.5))
        return 5
    }
}

// === 3e. .task với TaskGroup (parallel fetching) ===

struct TaskGroupDemo: View {
    @State private var data: (user: String, posts: [String], count: Int)?
    
    var body: some View {
        Group {
            if let data {
                VStack {
                    Text(data.user)
                    Text("\(data.posts.count) posts")
                    Text("\(data.count) notifications")
                }
            } else {
                ProgressView()
            }
        }
        .task {
            // Fetch tất cả cùng lúc, chờ TẤT CẢ xong
            async let user = fetchUser()
            async let posts = fetchPosts()
            async let count = fetchNotificationCount()
            
            data = await (user, posts, count)
        }
    }
    
    func fetchUser() async -> String { "Huy" }
    func fetchPosts() async -> [String] { ["Post 1"] }
    func fetchNotificationCount() async -> Int { 5 }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  4. .onChange(of:) — QUAN SÁT GIÁ TRỊ THAY ĐỔI          ║
// ╚══════════════════════════════════════════════════════════╝

// .onChange fire khi giá trị observed THAY ĐỔI (Equatable comparison).
// KHÔNG fire lần đầu (initial value) — chỉ khi CHANGE.

// === 4a. iOS 17+ API (recommended) ===

struct OnChangeNewAPI: View {
    @State private var text = ""
    @State private var selection = 0
    
    var body: some View {
        VStack {
            TextField("Search", text: $text)
            Picker("Tab", selection: $selection) {
                Text("A").tag(0)
                Text("B").tag(1)
            }
        }
        // iOS 17+: closure nhận (oldValue, newValue)
        .onChange(of: text) { oldValue, newValue in
            print("Text: '\(oldValue)' → '\(newValue)'")
            // Dùng old + new để so sánh, validate, debounce
        }
        .onChange(of: selection) { oldValue, newValue in
            print("Tab: \(oldValue) → \(newValue)")
        }
    }
}

// === 4b. iOS 14-16 API (legacy, vẫn hoạt động) ===
// .onChange(of: text) { newValue in ... }
// Không có oldValue parameter

// === 4c. .onChange với initial: true (iOS 17+) ===

struct OnChangeInitialDemo: View {
    @State private var filter = "all"
    
    var body: some View {
        Text("Filter: \(filter)")
            .onChange(of: filter, initial: true) { oldValue, newValue in
                // initial: true → fire NGAY LẬP TỨC khi view appear
                // với oldValue == newValue == giá trị ban đầu
                //
                // Thay thế pattern: .onAppear { process(filter) }
                //                   .onChange(of: filter) { process($1) }
                print("Filter changed: \(newValue)")
            }
    }
}

// === 4d. onChange với Equatable check ===

struct EquatableChangeDemo: View {
    @State private var user = User(name: "Huy", age: 25)
    
    var body: some View {
        VStack {
            TextField("Name", text: $user.name)
            Stepper("Age: \(user.age)", value: $user.age)
        }
        // ⚠️ User phải conform Equatable
        // onChange fire khi BẤT KỲ property nào thay đổi
        .onChange(of: user) { old, new in
            print("User changed: \(old) → \(new)")
        }
    }
}

struct User: Equatable {
    var name: String
    var age: Int
}

// onChange RULES:
// - Giá trị phải Equatable
// - So sánh old == new → chỉ fire khi KHÁC
// - Chạy trên MAIN THREAD (synchronous)
// - Có thể có NHIỀU .onChange trên cùng 1 view
// - KHÔNG fire cho initial value (trừ khi initial: true)
// - Fire SAU body recompute, TRƯỚC next render cycle


// ╔══════════════════════════════════════════════════════════╗
// ║  5. SCENE PHASE — APP LIFECYCLE                           ║
// ╚══════════════════════════════════════════════════════════╝

struct ScenePhaseLifecycle: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastRefresh = Date.now
    
    var body: some View {
        Text("Content")
        // scenePhase thay đổi khi app ↔ foreground/background
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App FOREGROUND + interactive
                // → Refresh data nếu stale
                if Date.now.timeIntervalSince(lastRefresh) > 300 {
                    refreshData()
                }
                
            case .inactive:
                // App visible nhưng KHÔNG interactive
                // (notification, app switcher, Control Center)
                // → Pause sensitive UI, blur banking data
                break
                
            case .background:
                // App vào BACKGROUND
                // → Save state, cancel network, schedule background task
                saveState()
                
            @unknown default:
                break
            }
        }
    }
    
    func refreshData() { lastRefresh = .now }
    func saveState() { }
}

// scenePhase vs .onAppear:
// .onAppear: view xuất hiện trong HIERARCHY
// scenePhase: TOÀN APP chuyển trạng thái
//
// Background → Foreground: scenePhase fires, onAppear KHÔNG fire
// Tab switch: onAppear fires, scenePhase KHÔNG fire


// ╔══════════════════════════════════════════════════════════╗
// ║  6. .onSubmit — KEYBOARD RETURN / ENTER                   ║
// ╚══════════════════════════════════════════════════════════╝

struct OnSubmitDemo: View {
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focus: Field?
    
    enum Field: Hashable { case username, password }
    
    var body: some View {
        Form {
            TextField("Username", text: $username)
                .focused($focus, equals: .username)
                .submitLabel(.next)
            
            SecureField("Password", text: $password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
        }
        // .onSubmit fire khi user nhấn Return/Enter/Go
        .onSubmit {
            // Scope: apply cho TẤT CẢ TextFields trong subtree
            switch focus {
            case .username:
                focus = .password   // Next field
            case .password:
                focus = nil         // Dismiss keyboard
                login()             // Perform action
            case nil:
                break
            }
        }
    }
    
    func login() { print("Login: \(username)") }
}

// .onSubmit SCOPE:
// Đặt trên parent → apply cho TẤT CẢ text fields con
// Đặt trên TextField cụ thể → chỉ apply cho field đó
// Có thể chain: parent .onSubmit + child .onSubmit (cả 2 fire)


// ╔══════════════════════════════════════════════════════════╗
// ║  7. .refreshable — PULL-TO-REFRESH                        ║
// ╚══════════════════════════════════════════════════════════╝

struct RefreshableDemo: View {
    @State private var items = (1...10).map { "Item \($0)" }
    
    var body: some View {
        List(items, id: \.self) { Text($0) }
            .refreshable {
                // ✅ Async context — await trực tiếp
                // ✅ SwiftUI TỰ ĐỘNG hiện/ẩn spinner
                // ✅ Spinner ẩn KHI await HOÀN THÀNH
                
                try? await Task.sleep(for: .seconds(1))
                items.insert("New \(Int.random(in: 100...999))", at: 0)
            }
        // User kéo xuống → spinner hiện
        // Async function hoàn thành → spinner ẩn
        // KHÔNG cần quản lý isLoading state!
    }
}

// .refreshable tạo refresh action trong Environment:
// @Environment(\.refresh) var refresh
// → Có thể gọi thủ công: await refresh?()


// ╔══════════════════════════════════════════════════════════╗
// ║  8. .onOpenURL & .onContinueUserActivity — DEEP LINKS    ║
// ╚══════════════════════════════════════════════════════════╝

struct DeepLinkLifecycle: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            Text("Home")
                .navigationDestination(for: String.self) { id in
                    Text("Detail: \(id)")
                }
        }
        // === URL Schemes: myapp://article/123 ===
        .onOpenURL { url in
            // Fire khi app mở từ URL scheme, Universal Link, widget
            if let id = url.pathComponents.last {
                path.append(id)
            }
        }
        // === Handoff / Spotlight / Siri ===
        .onContinueUserActivity("com.myapp.viewArticle") { activity in
            if let id = activity.userInfo?["articleID"] as? String {
                path.append(id)
            }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  9. .onKeyPress — KEYBOARD EVENTS (iOS 17+)              ║
// ╚══════════════════════════════════════════════════════════╝

struct OnKeyPressDemo: View {
    @State private var output = ""
    
    var body: some View {
        VStack {
            Text(output)
                .font(.title)
            Text("Nhấn phím bất kỳ (cần hardware keyboard)")
                .font(.caption)
        }
        .focusable() // View phải focusable để nhận key events
        .onKeyPress { press in
            // Fire cho MỌI key press khi view có focus
            output = "Key: \(press.characters)"
            return .handled // .handled hoặc .ignored
        }
        // Specific key:
        .onKeyPress(.return) {
            output = "Enter pressed!"
            return .handled
        }
        // Key combination:
        .onKeyPress(characters: .alphanumerics, phases: .down) { press in
            output = "Alphanumeric: \(press.characters)"
            return .handled
        }
    }
}

// .onKeyPress dùng cho:
// - Keyboard shortcuts trong iPad/Mac apps
// - Game controls
// - Custom text input handling
// - Accessibility keyboard navigation


// ╔══════════════════════════════════════════════════════════╗
// ║  10. SCROLL LIFECYCLE (iOS 17-18+)                        ║
// ╚══════════════════════════════════════════════════════════╝

struct ScrollLifecycleDemo: View {
    @State private var visibleItems: Set<Int> = []
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<50) { i in
                    Text("Row \(i)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            visibleItems.contains(i)
                                ? Color.blue.opacity(0.1)
                                : Color.gray.opacity(0.05),
                            in: .rect(cornerRadius: 8)
                        )
                    // === iOS 18+: onScrollVisibilityChange ===
                    // .onScrollVisibilityChange(threshold: 0.5) { visible in
                    //     if visible { visibleItems.insert(i) }
                    //     else { visibleItems.remove(i) }
                    // }
                    // threshold: 0.5 = fire khi 50% view visible
                }
            }
            .padding()
        }
        // === iOS 18+: onScrollGeometryChange ===
        // .onScrollGeometryChange(for: CGFloat.self) { geo in
        //     geo.contentOffset.y
        // } action: { _, newOffset in
        //     scrollOffset = newOffset
        // }
        
        // === iOS 17: scrollPosition ===
        // .scrollPosition(id: $scrolledID)
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  11. .id() — FORCE IDENTITY RESET                         ║
// ╚══════════════════════════════════════════════════════════╝

// .id() thay đổi IDENTITY của view → SwiftUI coi là VIEW MỚI
// → Destroy cũ (onDisappear) + Create mới (onAppear, task restart)

struct IDResetDemo: View {
    @State private var refreshToken = UUID()
    @State private var data: [String] = []
    
    var body: some View {
        VStack {
            Button("Force Reload") {
                // Đổi id → SwiftUI destroy + recreate toàn bộ List
                // → .task fire LẠI → fetch data mới
                refreshToken = UUID()
            }
            
            List(data, id: \.self) { Text($0) }
                .task {
                    data = await fetchData()
                }
                .id(refreshToken)
            // Mỗi khi refreshToken đổi:
            // 1. List cũ: .onDisappear, .task cancelled
            // 2. List mới: .onAppear, .task started
            // 3. @State bên trong List bị RESET
        }
    }
    
    func fetchData() async -> [String] {
        try? await Task.sleep(for: .seconds(0.5))
        return (1...10).map { "Item \(Int.random(in: 1...100))" }
    }
}

// ⚠️ .id() reset TẤT CẢ state bên trong view:
// - @State reset về initial
// - @FocusState reset
// - ScrollView scroll về đầu
// - Animation state reset
// → Dùng cẩn thận! Chỉ khi THẬT SỰ cần force recreate.


// ╔══════════════════════════════════════════════════════════╗
// ║  12. PRODUCTION — COMPLETE SCREEN LIFECYCLE               ║
// ╚══════════════════════════════════════════════════════════╝

// Pattern chuẩn kết hợp TẤT CẢ lifecycle modifiers:

@Observable
final class ProductListViewModel {
    var products: [String] = []
    var isLoading = false
    var error: Error?
    var searchQuery = ""
    var sortOrder = "newest"
    
    func load(category: String) async {
        isLoading = true
        defer { isLoading = false }
        
        try? await Task.sleep(for: .seconds(0.5))
        guard !Task.isCancelled else { return }
        
        products = (1...20).map { "\(category) Product \($0) [\(sortOrder)]" }
    }
    
    func refresh() async {
        try? await Task.sleep(for: .seconds(1))
        products.insert("Refreshed \(Int.random(in: 100...999))", at: 0)
    }
}

struct ProductListScreen: View {
    @State private var vm = ProductListViewModel()
    @State private var selectedCategory = "all"
    @State private var isAnimated = false
    @Environment(\.scenePhase) private var scenePhase
    
    let screenName = "ProductList"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("all")
                    Text("Tech").tag("tech")
                    Text("Design").tag("design")
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                List(vm.products, id: \.self) { product in
                    Text(product)
                        .opacity(isAnimated ? 1 : 0)
                }
                .overlay {
                    if vm.isLoading && vm.products.isEmpty {
                        ProgressView("Đang tải...")
                    }
                }
            }
            .navigationTitle("Products")
            
            // ──────── LIFECYCLE MODIFIERS ────────
            
            // 1️⃣ SYNC SETUP — animation, analytics
            .onAppear {
                // Entrance animation
                withAnimation(.easeOut(duration: 0.3)) {
                    isAnimated = true
                }
                // Analytics
                Analytics.trackScreen(screenName)
            }
            
            // 2️⃣ ASYNC LOAD — fetch data, auto-cancel, restart on change
            .task(id: selectedCategory) {
                // Fire: appear + category thay đổi
                // Auto-cancel task cũ khi category đổi
                await vm.load(category: selectedCategory)
            }
            
            // 3️⃣ VALUE OBSERVATION — respond to sort change
            .onChange(of: vm.sortOrder) { _, newOrder in
                // Sync response: không cần async
                Analytics.track("sort_changed", params: ["order": newOrder])
            }
            
            // 4️⃣ PULL-TO-REFRESH — user-initiated reload
            .refreshable {
                await vm.refresh()
            }
            
            // 5️⃣ APP LIFECYCLE — background/foreground handling
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Refresh stale data khi app trở lại
                    Task { await vm.load(category: selectedCategory) }
                }
            }
            
            // 6️⃣ DEEP LINK — handle external navigation
            .onOpenURL { url in
                if let category = url.queryParameters?["category"] {
                    selectedCategory = category
                    // → .task(id:) tự fire vì selectedCategory đổi
                }
            }
            
            // 7️⃣ CLEANUP — stop tracking, save state
            .onDisappear {
                isAnimated = false
                Analytics.trackScreenExit(screenName)
            }
        }
    }
}

// Analytics placeholder
enum Analytics {
    static func trackScreen(_ name: String) { print("📊 Screen: \(name)") }
    static func trackScreenExit(_ name: String) { print("📊 Exit: \(name)") }
    static func track(_ event: String, params: [String: String] = [:]) {
        print("📊 Event: \(event) \(params)")
    }
}

extension URL {
    var queryParameters: [String: String]? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  13. MODIFIER CHAINING ORDER — THỨ TỰ ĐẶT MODIFIERS     ║
// ╚══════════════════════════════════════════════════════════╝

// Lifecycle modifiers KHÔNG phụ thuộc vào thứ tự đặt
// (khác với visual modifiers như .padding, .background).
// Nhưng convention giúp code DỄ ĐỌC hơn:

struct RecommendedOrder: View {
    var body: some View {
        Text("Content")
            // ① Visual modifiers (padding, background, font...)
            .padding()
            .background(.gray.opacity(0.1))
            .font(.body)
            
            // ② Navigation modifiers
            .navigationTitle("Title")
            .navigationDestination(for: String.self) { _ in Text("") }
            
            // ③ Lifecycle: appear/disappear
            .onAppear { }
            .onDisappear { }
            
            // ④ Lifecycle: async work
            .task { }
            .task(id: "") { }
            
            // ⑤ Lifecycle: value observation
            .onChange(of: "") { _, _ in }
            
            // ⑥ Lifecycle: user interaction
            .onSubmit { }
            .refreshable { }
            
            // ⑦ Lifecycle: external events
            .onOpenURL { _ in }
            .onContinueUserActivity("") { _ in }
            
            // ⑧ Presentation modifiers (sheet, alert...)
            // .sheet(isPresented:) { }
            // .alert(isPresented:) { }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  14. TỔNG HỢP — DECISION MATRIX                          ║
// ╚══════════════════════════════════════════════════════════╝

// ┌──────────────────────────┬───────────────────────────────────┐
// │ Tôi cần...               │ Dùng modifier nào?                │
// ├──────────────────────────┼───────────────────────────────────┤
// │ Sync setup khi appear    │ .onAppear { }                     │
// │ Async fetch khi appear   │ .task { }                         │
// │ Fetch + restart khi      │ .task(id: dependency) { }         │
// │   dependency thay đổi    │                                   │
// │ Cleanup khi disappear    │ .onDisappear { }                  │
// │ React khi value đổi      │ .onChange(of:) { }                │
// │ React khi appear + đổi   │ .onChange(of:, initial: true)     │
// │                          │ HOẶC .task(id:)                   │
// │ Pull-to-refresh          │ .refreshable { }                  │
// │ Keyboard Return action   │ .onSubmit { }                     │
// │ App foreground/background│ .onChange(of: scenePhase) { }     │
// │ Handle URL schemes       │ .onOpenURL { }                    │
// │ Handle Handoff/Spotlight │ .onContinueUserActivity { }       │
// │ Keyboard shortcuts       │ .onKeyPress { }                   │
// │ Force recreate view      │ .id(changingValue)                │
// │ Track scroll position    │ .scrollPosition(id:) / iOS 18 API│
// │ Debounced async search   │ .task(id: query) + sleep          │
// │ One-time only execution  │ .onAppear + guard hasAppeared     │
// │                          │ HOẶC custom .onFirstAppear        │
// └──────────────────────────┴───────────────────────────────────┘


// ╔══════════════════════════════════════════════════════════╗
// ║  15. COMMON PITFALLS & BEST PRACTICES                    ║
// ╚══════════════════════════════════════════════════════════╝

// ❌ PITFALL 1: .onAppear cho async work
//    .onAppear { Task { await fetch() } } // Task KHÔNG auto-cancel!
//    ✅ FIX: .task { await fetch() } — auto-cancel khi disappear

// ❌ PITFALL 2: .onChange fire cho initial value
//    .onChange(of: x) { ... } // KHÔNG fire cho giá trị ban đầu
//    ✅ FIX: .onChange(of: x, initial: true) nếu cần
//            Hoặc .task(id: x) (fire cả lúc appear)

// ❌ PITFALL 3: .task(id:) với non-Equatable type
//    .task(id: complexObject) // Object phải Equatable để so sánh!
//    ✅ FIX: Dùng primitive id: .task(id: object.id)

// ❌ PITFALL 4: Heavy sync work trong .onAppear
//    .onAppear { process1MillionRecords() } // Block main → freeze
//    ✅ FIX: .task { await processInBackground() }

// ❌ PITFALL 5: Quên cleanup trong .onDisappear
//    .onAppear { startTimer() }
//    // Timer chạy MÃI MÃII dù view đã disappear → memory leak
//    ✅ FIX: .onDisappear { stopTimer() }
//            Hoặc dùng .task { } → auto-cancel

// ❌ PITFALL 6: Expect .onAppear khi dismiss sheet
//    Parent.onAppear KHÔNG fire khi sheet dismiss
//    ✅ FIX: .sheet(onDismiss: { refresh() })
//            Hoặc .onChange(of: showSheet) { if !$0 { refresh() } }

// ❌ PITFALL 7: .onChange cascade → infinite loop
//    .onChange(of: a) { a = transform(a) } // a thay đổi → fire lại!
//    ✅ FIX: Guard: if newValue != expected { a = transform(a) }

// ❌ PITFALL 8: Multiple .task bị sequential thay vì parallel
//    .task { await fetchA(); await fetchB() } // B chờ A xong
//    ✅ FIX: async let a = fetchA(); async let b = fetchB()
//            Hoặc 2 .task riêng biệt → chạy parallel

// ✅ BEST PRACTICES:
// 1. .task cho async, .onAppear cho sync — KHÔNG MIX
// 2. .task(id:) thay combo .onAppear + .onChange
// 3. .onDisappear PAIR với .onAppear cho mọi setup/cleanup
// 4. .onChange(of:, initial: true) khi cần fire cho giá trị ban đầu
// 5. Guard pattern trong .onAppear cho one-time execution
// 6. Nhiều .task trên 1 view → chạy PARALLEL (concurrent)
// 7. async let cho parallel fetching TRONG 1 .task
// 8. .refreshable cho pull-to-refresh (spinner tự quản lý)
// 9. .id() force recreate — dùng CẨN THẬN (reset tất cả state)
// 10. Convention: visual → navigation → lifecycle → presentation
// 11. Test: tab switch, navigation pop, sheet dismiss, background
// 12. scenePhase cho app-level lifecycle, onAppear cho view-level
```

---

Đây là chủ đề tổng hợp cực kỳ quan trọng — gom tất cả lifecycle modifiers vào một bức tranh thống nhất để hiểu đúng thứ tự, timing, và cách chúng phối hợp với nhau. Mình sẽ giải thích toàn bộ.Mình đã tổng hợp toàn bộ hệ thống View Lifecycle Modifiers trong 15 phần. Đây là bức tranh toàn cảnh mà mọi SwiftUI developer cần nắm.

**Điểm quan trọng nhất — Phần 1: Thứ tự firing sequence**. Khi view xuất hiện: `init → @State init → .onAppear → .task starts → render → user interacts → .onChange → .task(id:) restarts → .task cancelled → .onDisappear → removed`. Hiểu đúng thứ tự này giúp debug mọi lifecycle bug.

**Bốn phần giá trị nhất:**

**Phần 3 — .task vs .onAppear**: Đây là quyết định quan trọng nhất. `.task` có 3 ưu điểm quyết định: async/await native, **auto-cancel khi disappear** (không memory leak), và `.task(id:)` **thay thế combo** `.onAppear + .onChange` chỉ bằng 1 modifier với auto-cancel task cũ khi id đổi. Nguyên tắc: sync → `.onAppear`, async → `.task`.

**Phần 4c — `.onChange(of:, initial: true)` (iOS 17+)**: Parameter `initial: true` giải quyết pattern cũ phải viết cả `.onAppear { process(value) }` + `.onChange(of: value) { process($1) }`. Giờ chỉ cần 1 modifier fire cho cả initial value + changes.

**Phần 11 — `.id()` force reset**: Modifier bí mật nhưng cực mạnh — đổi `.id()` khiến SwiftUI coi view là **hoàn toàn mới**: destroy cũ (onDisappear + task cancel) + create mới (onAppear + task restart + state reset). Dùng cho "force reload" pattern nhưng **cẩn thận** vì reset tất cả internal state.

**Phần 12 — Complete Screen Lifecycle**: Production pattern kết hợp **7 lifecycle modifiers** trên 1 screen theo đúng thứ tự: `.onAppear` (sync animation + analytics) → `.task(id:)` (async fetch + auto-restart) → `.onChange` (value observation) → `.refreshable` (pull-to-refresh) → `.onChange(of: scenePhase)` (background/foreground) → `.onOpenURL` (deep links) → `.onDisappear` (cleanup). Đây là template chuẩn cho mọi production screen.

**Decision Matrix ở Phần 14** là reference nhanh nhất — "Tôi cần X → dùng modifier Y". Đặc biệt: debounced search = `.task(id: query)` + sleep, one-time execution = `.onAppear` + guard, app lifecycle = `.onChange(of: scenePhase)`.

Huy muốn mình đi tiếp sang chủ đề nào khác không?
