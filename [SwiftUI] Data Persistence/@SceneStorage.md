```Swift
// ============================================================
// @SceneStorage TRONG SWIFTUI — GIẢI THÍCH CHI TIẾT
// ============================================================
// @SceneStorage lưu trữ và khôi phục STATE CỦA UI cho mỗi scene
// (window) khi app bị KILL bởi hệ thống rồi KHỞI ĐỘNG LẠI.
//
// Bài toán nó giải quyết:
// 1. User đang đọc bài viết ở tab 2, scroll xuống 70%
// 2. User chuyển sang app khác
// 3. iOS kill app vì thiếu memory (background termination)
// 4. User quay lại app → @SceneStorage KHÔI PHỤC:
//    - Đúng tab 2
//    - Đúng bài viết
//    - Đúng vị trí scroll
//
// Tương đương: NSUserActivity / UIStateRestoration trong UIKit.
//
// Key characteristics:
// - Lưu PER-SCENE (mỗi window riêng biệt — quan trọng trên iPad)
// - TỰ ĐỘNG save/restore bởi SwiftUI
// - Chỉ hỗ trợ lightweight value types
// - KHÔNG phải persistent storage dài hạn
// - KHÔNG đồng bộ giữa các devices
// ============================================================

import SwiftUI


// ╔══════════════════════════════════════════════════════════╗
// ║  1. CÚ PHÁP CƠ BẢN                                     ║
// ╚══════════════════════════════════════════════════════════╝

struct BasicSceneStorageDemo: View {
    // @SceneStorage("unique_key") var name: Type = defaultValue
    
    // === 1a. String ===
    @SceneStorage("draft_text") private var draftText = ""
    // Key "draft_text": unique identifier cho giá trị này
    // Giá trị "" = default khi không có gì được restore
    
    // === 1b. Int ===
    @SceneStorage("selected_tab") private var selectedTab = 0
    
    // === 1c. Double ===
    @SceneStorage("scroll_offset") private var scrollOffset = 0.0
    
    // === 1d. Bool ===
    @SceneStorage("show_completed") private var showCompleted = false
    
    // === 1e. URL ===
    @SceneStorage("last_url") private var lastURL: URL?
    
    // === 1f. Data ===
    @SceneStorage("small_data") private var smallData: Data?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            VStack(spacing: 16) {
                Text("Draft sẽ được khôi phục khi app restart")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $draftText)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.gray.opacity(0.2))
                    )
                
                Toggle("Hiện đã hoàn thành", isOn: $showCompleted)
                
                Text("Tất cả giá trị trên tự động persist per-scene")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .tabItem {
                Image(systemName: "doc.text")
                Text("Editor")
            }
            .tag(0)
            
            Text("Tab 2 Content")
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(1)
        }
        // selectedTab = 0 hoặc 1 → tự restore khi app relaunch
    }
}

// SUPPORTED TYPES:
// ┌──────────────┬──────────────────────────────────────────┐
// │ Type         │ Ghi chú                                  │
// ├──────────────┼──────────────────────────────────────────┤
// │ Bool         │ ✅                                       │
// │ Int          │ ✅                                       │
// │ Double       │ ✅                                       │
// │ String       │ ✅                                       │
// │ URL          │ ✅                                       │
// │ Data         │ ✅ (giữ nhỏ, < vài KB)                  │
// │ RawRepresentable │ ✅ (enum với RawValue là trên)       │
// │ Optional<T>  │ ✅ (T là các type trên)                 │
// ├──────────────┼──────────────────────────────────────────┤
// │ Array        │ ❌ Không hỗ trợ trực tiếp               │
// │ Dictionary   │ ❌ Không hỗ trợ trực tiếp               │
// │ Custom struct│ ❌ Không hỗ trợ trực tiếp               │
// │ Codable      │ ❌ (phải convert qua Data)              │
// └──────────────┴──────────────────────────────────────────┘


// ╔══════════════════════════════════════════════════════════╗
// ║  2. CƠ CHẾ HOẠT ĐỘNG — KHI NÀO SAVE / RESTORE?         ║
// ╚══════════════════════════════════════════════════════════╝

// @SceneStorage hoạt động theo vòng đời SCENE:
//
// ┌─────────────────────────────────────────────────────────┐
// │                    SAVE                                  │
// │                                                          │
// │  1. User thay đổi giá trị (type vào TextField, chọn tab)│
// │  2. SwiftUI TỰ ĐỘNG persist vào scene storage           │
// │  3. Không cần gọi save() thủ công                       │
// │  4. Save xảy ra khi:                                    │
// │     - Scene vào background                              │
// │     - Scene bị suspended                                │
// │     - Giá trị thay đổi (debounced bởi SwiftUI)         │
// └─────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────┐
// │                   RESTORE                                │
// │                                                          │
// │  1. App bị kill bởi iOS (low memory, system pressure)   │
// │  2. User tap app icon → iOS tạo scene MỚI               │
// │  3. SwiftUI đọc scene storage → inject vào @SceneStorage│
// │  4. UI hiển thị ĐÚNG trạng thái trước khi bị kill      │
// └─────────────────────────────────────────────────────────┘
//
// ⚠️ KHÔNG RESTORE khi:
// - User FORCE QUIT app (swipe up trong App Switcher)
//   → iOS xoá scene storage → app khởi động fresh
// - App bị uninstall rồi reinstall
// - .constant binding (không thực sự SceneStorage)

struct LifecycleExplanation: View {
    @SceneStorage("counter") private var counter = 0
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Counter: \(counter)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            
            HStack(spacing: 16) {
                Button("-") { counter -= 1 }
                Button("+") { counter += 1 }
            }
            .font(.title)
            .buttonStyle(.bordered)
            
            VStack(spacing: 4) {
                Text("1. Thay đổi counter")
                Text("2. Chuyển sang app khác (background)")
                Text("3. iOS kill app (simulate: Xcode stop)")
                Text("4. Mở lại app → counter được khôi phục")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // @SceneStorage tự save — không cần làm gì ở đây
            // Nhưng có thể log để debug:
            print("Phase: \(newPhase) | Counter: \(counter)")
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  3. @SceneStorage vs @AppStorage vs @State               ║
// ╚══════════════════════════════════════════════════════════╝

// ┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
// │                  │ @State           │ @SceneStorage    │ @AppStorage      │
// ├──────────────────┼──────────────────┼──────────────────┼──────────────────┤
// │ Persist          │ ❌ Chỉ in-memory│ ✅ Per-scene     │ ✅ UserDefaults  │
// │ Scope            │ View instance    │ Per SCENE/window │ TOÀN APP         │
// │ Survive app kill │ ❌              │ ✅ (system kill) │ ✅ (mọi trường   │
// │                  │                  │ ❌ (force quit)  │     hợp)         │
// │ Share across     │ ❌              │ ❌ (mỗi scene    │ ✅ Tất cả scenes │
// │ scenes/windows   │                  │     riêng biệt)  │     dùng chung  │
// │ iPad multi-window│ Mỗi window riêng│ Mỗi window riêng │ Chung tất cả    │
// │ Dùng cho         │ Transient UI    │ UI state restore │ User preferences │
// │                  │ (animation,     │ (tab, scroll,    │ (theme, language,│
// │                  │  toggle temp)   │  draft, position)│  settings on/off)│
// │ iCloud sync      │ ❌              │ ❌              │ Qua NSUbiquitous │
// │ Storage          │ Memory          │ System managed   │ UserDefaults file│
// │ Types            │ Any             │ Primitives only  │ Primitives +     │
// │                  │                  │                  │ RawRepresentable │
// └──────────────────┴──────────────────┴──────────────────┴──────────────────┘

// 📌 NGUYÊN TẮC CHỌN:
//
// "User MUỐN giá trị này không?"
//   → YES (theme, notifications): @AppStorage (UserDefaults)
//   → NO (đang xem tab nào, scroll đến đâu): @SceneStorage
//
// "Giá trị này cần tồn tại sau force quit?"
//   → YES: @AppStorage
//   → NO (chỉ cần restore sau system kill): @SceneStorage
//
// "Giá trị chia sẻ giữa các windows trên iPad?"
//   → YES: @AppStorage
//   → NO (mỗi window trạng thái riêng): @SceneStorage

struct ComparisonDemo: View {
    // @State: mất khi app terminate (bất kỳ cách nào)
    @State private var tempCounter = 0
    
    // @SceneStorage: restore sau system kill, mất sau force quit
    @SceneStorage("scene_counter") private var sceneCounter = 0
    
    // @AppStorage: persist MÃI cho đến khi xoá app
    @AppStorage("app_counter") private var appCounter = 0
    
    var body: some View {
        VStack(spacing: 24) {
            CounterRow(title: "@State (memory only)", count: tempCounter) {
                tempCounter += 1
            }
            
            CounterRow(title: "@SceneStorage (per-scene)", count: sceneCounter) {
                sceneCounter += 1
            }
            
            CounterRow(title: "@AppStorage (UserDefaults)", count: appCounter) {
                appCounter += 1
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Test: tăng cả 3, rồi:").font(.caption.bold())
                Text("• Background + iOS kill → @State mất, 2 cái kia giữ")
                Text("• Force quit → @State + @SceneStorage mất, @AppStorage giữ")
                Text("• iPad 2 windows → @SceneStorage KHÁC nhau mỗi window")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding()
            .background(.gray.opacity(0.06), in: .rect(cornerRadius: 8))
        }
        .padding()
    }
}

struct CounterRow: View {
    let title: String
    let count: Int
    let increment: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text("\(count)")
                    .font(.title.bold().monospaced())
            }
            Spacer()
            Button("+", action: increment)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.gray.opacity(0.05), in: .rect(cornerRadius: 12))
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  4. ENUM VỚI @SceneStorage (RawRepresentable)            ║
// ╚══════════════════════════════════════════════════════════╝

// Enum phải conform RawRepresentable với RawValue là
// String, Int, hoặc Double.

enum AppTab: String, CaseIterable {
    case home, search, notifications, profile
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .notifications: return "Notifications"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .notifications: return "bell.fill"
        case .profile: return "person.fill"
        }
    }
}

enum SortOrder: String {
    case newest, oldest, popular, alphabetical
}

enum ViewMode: Int {
    case list = 0, grid = 1, compact = 2
}

struct EnumSceneStorageDemo: View {
    // ✅ Enum với String RawValue
    @SceneStorage("selected_tab") private var selectedTab: AppTab = .home
    
    // ✅ Enum với String RawValue
    @SceneStorage("sort_order") private var sortOrder: SortOrder = .newest
    
    // ✅ Enum với Int RawValue
    @SceneStorage("view_mode") private var viewMode: ViewMode = .list
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                VStack(spacing: 16) {
                    Text(tab.title)
                        .font(.largeTitle)
                    Text("Sort: \(sortOrder.rawValue)")
                    Text("View: \(viewMode.rawValue)")
                }
                .tabItem {
                    Image(systemName: tab.icon)
                    Text(tab.title)
                }
                .tag(tab)
            }
        }
        // Khi app restart: selectedTab, sortOrder, viewMode
        // đều được khôi phục đúng giá trị trước đó
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  5. LƯU CODABLE QUA DATA CONVERSION                     ║
// ╚══════════════════════════════════════════════════════════╝

// @SceneStorage không trực tiếp hỗ trợ Codable/Array/Dictionary.
// Workaround: convert qua Data hoặc String (JSON).

// === 5a. Codable struct → Data ===

struct DraftPost: Codable {
    var title: String
    var body: String
    var tags: [String]
}

struct CodableSceneStorageDemo: View {
    @SceneStorage("draft_post_data") private var draftData: Data?
    
    @State private var draft = DraftPost(title: "", body: "", tags: [])
    
    var body: some View {
        Form {
            TextField("Tiêu đề", text: $draft.title)
            TextEditor(text: $draft.body)
                .frame(height: 100)
            Text("Tags: \(draft.tags.joined(separator: ", "))")
        }
        // Save draft → Data khi thay đổi
        .onChange(of: draft.title) { _, _ in saveDraft() }
        .onChange(of: draft.body) { _, _ in saveDraft() }
        // Restore draft từ Data khi appear
        .onAppear { loadDraft() }
    }
    
    private func saveDraft() {
        draftData = try? JSONEncoder().encode(draft)
    }
    
    private func loadDraft() {
        guard let data = draftData,
              let restored = try? JSONDecoder().decode(DraftPost.self, from: data)
        else { return }
        draft = restored
    }
}


// === 5b. Array<String> → JSON String ===

struct ArraySceneStorageDemo: View {
    @SceneStorage("recent_searches") private var recentSearchesJSON = "[]"
    
    @State private var recentSearches: [String] = []
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button("Search") {
                    addSearch(searchText)
                    searchText = ""
                }
            }
            
            ForEach(recentSearches, id: \.self) { search in
                Text(search)
            }
        }
        .padding()
        .onAppear { decodeSearches() }
    }
    
    private func addSearch(_ query: String) {
        guard !query.isEmpty else { return }
        recentSearches.insert(query, at: 0)
        if recentSearches.count > 10 { recentSearches.removeLast() }
        encodeSearches()
    }
    
    private func encodeSearches() {
        if let data = try? JSONEncoder().encode(recentSearches),
           let json = String(data: data, encoding: .utf8) {
            recentSearchesJSON = json
        }
    }
    
    private func decodeSearches() {
        if let data = recentSearchesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = decoded
        }
    }
}


// === 5c. Reusable Property Wrapper (Clean approach) ===

// Tạo wrapper cho phép dùng Codable với @SceneStorage-like behavior
// bằng cách kết hợp @SceneStorage(Data) + computed property

struct CodableSceneState<T: Codable>: DynamicProperty {
    @SceneStorage private var data: Data?
    private let defaultValue: T
    
    init(_ key: String, defaultValue: T) {
        self._data = SceneStorage(wrappedValue: nil, key)
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            guard let data else { return defaultValue }
            return (try? JSONDecoder().decode(T.self, from: data)) ?? defaultValue
        }
        nonmutating set {
            data = try? JSONEncoder().encode(newValue)
        }
    }
}

// Sử dụng:
struct CleanCodableDemo: View {
    // Dùng giống @SceneStorage nhưng hỗ trợ Codable
    @CodableSceneState("draft_v2", defaultValue: DraftPost(title: "", body: "", tags: []))
    var draft: DraftPost
    
    var body: some View {
        Form {
            TextField("Title", text: Binding(
                get: { draft.title },
                set: { draft.title = $0 }
            ))
            // ⚠️ Binding phức tạp hơn vì CodableSceneState
            // không trả về Binding trực tiếp
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  6. iPAD MULTI-WINDOW — PER-SCENE BEHAVIOR               ║
// ╚══════════════════════════════════════════════════════════╝

// Trên iPad, user có thể mở NHIỀU WINDOWS của cùng 1 app.
// @SceneStorage lưu RIÊNG cho mỗi window.

struct MultiWindowDemo: View {
    // Mỗi window có selectedTab RIÊNG
    @SceneStorage("selected_tab") private var selectedTab: AppTab = .home
    
    // Mỗi window có draft RIÊNG
    @SceneStorage("draft_text") private var draftText = ""
    
    // Mỗi window có scroll position RIÊNG
    @SceneStorage("scroll_position") private var scrollPosition = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Window-specific state:")
                    .font(.headline)
                
                Text("Tab: \(selectedTab.rawValue)")
                Text("Draft: \"\(draftText.prefix(20))...\"")
                Text("Scroll: \(scrollPosition)")
                
                TextEditor(text: $draftText)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.gray.opacity(0.2))
                    )
            }
            .padding()
            .navigationTitle("Window Demo")
        }
    }
}

// iPad Multi-Window Scenario:
//
// Window 1                    Window 2
// ┌──────────────────┐       ┌──────────────────┐
// │ Tab: Home        │       │ Tab: Profile     │
// │ Draft: "Hello..."│       │ Draft: "Dear..." │
// │ Scroll: 150      │       │ Scroll: 0        │
// └──────────────────┘       └──────────────────┘
//        ↓                          ↓
//   @SceneStorage              @SceneStorage
//   (Scene 1 storage)          (Scene 2 storage)
//        ↓                          ↓
//   Riêng biệt, KHÔNG chia sẻ giữa 2 windows
//
// Nếu dùng @AppStorage thay vì @SceneStorage:
// → Cả 2 windows SHARE cùng giá trị
// → Đổi tab ở Window 1 → Window 2 cũng đổi theo! (sai behavior)


// ╔══════════════════════════════════════════════════════════╗
// ║  7. PRODUCTION PATTERNS                                   ║
// ╚══════════════════════════════════════════════════════════╝

// === 7a. Tab + Navigation State Restoration ===

struct AppStateRestoration: View {
    // Scene-level: mỗi window có tab riêng
    @SceneStorage("active_tab") private var activeTab: AppTab = .home
    
    // Scene-level: navigation path cho mỗi tab
    @SceneStorage("home_nav_id") private var homeNavID: String?
    @SceneStorage("search_query") private var lastSearchQuery = ""
    
    var body: some View {
        TabView(selection: $activeTab) {
            NavigationStack {
                List {
                    ForEach(0..<20) { i in
                        NavigationLink("Item \(i)", value: "item-\(i)")
                    }
                }
                .navigationTitle("Home")
                .navigationDestination(for: String.self) { id in
                    Text("Detail: \(id)")
                        .onAppear { homeNavID = id }
                        .onDisappear { homeNavID = nil }
                }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)
            
            NavigationStack {
                VStack {
                    TextField("Search...", text: $lastSearchQuery)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                    // lastSearchQuery tự restore → user thấy lại query cũ
                    
                    Text("Results for: \(lastSearchQuery)")
                }
                .navigationTitle("Search")
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            .tag(AppTab.search)
            
            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(AppTab.profile)
        }
    }
}


// === 7b. Document Editor — Draft Auto-Save ===

struct DocumentEditorDemo: View {
    // Mỗi window có draft riêng (iPad multi-window)
    @SceneStorage("doc_title") private var title = ""
    @SceneStorage("doc_body") private var body_text = ""
    @SceneStorage("doc_cursor_position") private var cursorPosition = 0
    @SceneStorage("doc_is_preview") private var isPreview = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isPreview {
                    // Preview mode
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title)
                                .font(.title.bold())
                            Text(body_text)
                                .font(.body)
                        }
                        .padding()
                    }
                } else {
                    // Edit mode
                    Form {
                        Section("Tiêu đề") {
                            TextField("Nhập tiêu đề", text: $title)
                        }
                        Section("Nội dung") {
                            TextEditor(text: $body_text)
                                .frame(minHeight: 200)
                        }
                    }
                }
            }
            .navigationTitle(title.isEmpty ? "New Document" : title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isPreview ? "Sửa" : "Xem trước") {
                        isPreview.toggle()
                    }
                }
            }
        }
        // Tất cả state (title, body, preview mode)
        // tự động restore khi app relaunch
    }
}


// === 7c. Reading Progress Tracker ===

struct ReadingProgressDemo: View {
    // Lưu tiến đọc cho scene này
    @SceneStorage("reading_article_id") private var articleID: String?
    @SceneStorage("reading_scroll_percent") private var scrollPercent = 0.0
    
    let articles = [
        ("article-1", "SwiftUI Layout System"),
        ("article-2", "Combine Framework Deep Dive"),
        ("article-3", "Swift Concurrency"),
    ]
    
    var body: some View {
        NavigationStack {
            List(articles, id: \.0) { id, title in
                NavigationLink {
                    ArticleReaderView(
                        articleID: id,
                        title: title,
                        savedProgress: articleID == id ? scrollPercent : 0,
                        onProgressChange: { progress in
                            articleID = id
                            scrollPercent = progress
                        }
                    )
                } label: {
                    HStack {
                        Text(title)
                        Spacer()
                        if articleID == id {
                            Text("\(Int(scrollPercent * 100))%")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Articles")
        }
    }
}

struct ArticleReaderView: View {
    let articleID: String
    let title: String
    let savedProgress: Double
    let onProgressChange: (Double) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title.bold())
                
                // Simulate long article
                ForEach(0..<20) { i in
                    Text("Paragraph \(i + 1): Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                }
            }
            .padding()
            // Track scroll progress
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onChange(of: geo.frame(in: .global).minY) { _, newY in
                            let progress = min(1, max(0, -newY / 1000))
                            onProgressChange(progress)
                        }
                }
            )
        }
        .navigationTitle(title)
    }
}


// === 7d. Filter/Sort State Preservation ===

struct FilterStateDemo: View {
    // Filter state — restore khi app restart
    @SceneStorage("filter_category") private var selectedCategory = "all"
    @SceneStorage("filter_sort") private var sortOrder: SortOrder = .newest
    @SceneStorage("filter_show_archived") private var showArchived = false
    @SceneStorage("filter_min_price") private var minPrice = 0.0
    @SceneStorage("filter_max_price") private var maxPrice = 1000.0
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filter summary
                HStack {
                    Text("Category: \(selectedCategory)")
                    Spacer()
                    Text("Sort: \(sortOrder.rawValue)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                
                // Content
                List {
                    Text("Filtered results here...")
                }
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // Sort
                        Picker("Sort", selection: $sortOrder) {
                            Text("Newest").tag(SortOrder.newest)
                            Text("Oldest").tag(SortOrder.oldest)
                            Text("Popular").tag(SortOrder.popular)
                        }
                        
                        // Archive toggle
                        Toggle("Show Archived", isOn: $showArchived)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        // Tất cả filter state tự động restore!
        // User không cần set lại filters sau khi app restart
    }
}


// === 7e. Multi-Step Form Progress ===

struct MultiStepFormDemo: View {
    @SceneStorage("form_step") private var currentStep = 0
    @SceneStorage("form_name") private var name = ""
    @SceneStorage("form_email") private var email = ""
    @SceneStorage("form_plan") private var selectedPlan = "free"
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress
            ProgressView(value: Double(currentStep), total: 2)
                .padding(.horizontal)
            
            // Step content
            Group {
                switch currentStep {
                case 0:
                    VStack(spacing: 16) {
                        Text("Bước 1: Thông tin").font(.title2.bold())
                        TextField("Họ tên", text: $name)
                            .textFieldStyle(.roundedBorder)
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                    }
                case 1:
                    VStack(spacing: 16) {
                        Text("Bước 2: Chọn gói").font(.title2.bold())
                        Picker("Plan", selection: $selectedPlan) {
                            Text("Free").tag("free")
                            Text("Pro").tag("pro")
                            Text("Enterprise").tag("enterprise")
                        }
                        .pickerStyle(.segmented)
                    }
                case 2:
                    VStack(spacing: 16) {
                        Text("Bước 3: Xác nhận").font(.title2.bold())
                        Text("Tên: \(name)")
                        Text("Email: \(email)")
                        Text("Gói: \(selectedPlan)")
                    }
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Quay lại") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button(currentStep < 2 ? "Tiếp" : "Hoàn tất") {
                    withAnimation {
                        if currentStep < 2 { currentStep += 1 }
                        else { submitForm() }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        // User đang ở bước 2, app bị kill → mở lại → đúng bước 2
        // Tất cả data đã nhập ở bước 1 vẫn còn
    }
    
    func submitForm() {
        // Reset after submit
        currentStep = 0
        name = ""
        email = ""
        selectedPlan = "free"
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  8. TESTING & DEBUGGING                                   ║
// ╚══════════════════════════════════════════════════════════╝

// === 8a. Test SceneStorage behavior ===
// 1. Chạy app trên Simulator
// 2. Thay đổi state (chọn tab, nhập text)
// 3. Trong Xcode: Stop app (⌘.)
//    → Simulate system kill
// 4. Run lại app
//    → @SceneStorage values ĐƯỢC restore
//
// 5. Trên Simulator: swipe up App Switcher → swipe kill app
//    → Force quit → @SceneStorage values BỊ XOÁ
//    → App khởi động fresh

// === 8b. Debug logging ===
struct DebugSceneStorage: View {
    @SceneStorage("debug_value") private var value = "default"
    
    var body: some View {
        VStack {
            Text("Value: \(value)")
            Button("Change") { value = "changed-\(Date.now.timeIntervalSince1970)" }
        }
        .onAppear {
            print("📦 SceneStorage restored: \(value)")
        }
        .onChange(of: value) { old, new in
            print("📦 SceneStorage changed: \(old) → \(new)")
        }
    }
}

// === 8c. Preview: @SceneStorage hoạt động bình thường ===
// Trong Xcode Preview, @SceneStorage hoạt động như @State
// (persist trong session preview, reset khi rebuild)

#Preview("SceneStorage Demo") {
    BasicSceneStorageDemo()
}


// ╔══════════════════════════════════════════════════════════╗
// ║  9. COMMON PITFALLS & BEST PRACTICES                     ║
// ╚══════════════════════════════════════════════════════════╝

// ❌ PITFALL 1: Lưu data lớn trong @SceneStorage
//    @SceneStorage("image_data") var imageData: Data?
//    → Scene storage cho LIGHTWEIGHT data
//    → Ảnh/video/file lớn sẽ gây chậm restore
//    ✅ FIX: Lưu FILE PATH hoặc ID, không lưu data
//            @SceneStorage("image_id") var imageID: String?

// ❌ PITFALL 2: Dùng @SceneStorage cho user preferences
//    @SceneStorage("dark_mode") var isDark = false
//    → Mỗi window trên iPad có theme KHÁC NHAU → confusing
//    ✅ FIX: @AppStorage cho settings TOÀN APP
//            @SceneStorage cho UI STATE per-window

// ❌ PITFALL 3: Key trùng nhau giữa các views
//    View A: @SceneStorage("value") var x = 0
//    View B: @SceneStorage("value") var y = "hello"
//    → CÙNG KEY, KHÁC TYPE → undefined behavior, có thể crash
//    ✅ FIX: Key UNIQUE và DESCRIPTIVE:
//            "editor_draft_title", "search_last_query"

// ❌ PITFALL 4: Expect persist sau force quit
//    User force quit → @SceneStorage BỊ XOÁ
//    ✅ FIX: Nếu data QUAN TRỌNG → dùng @AppStorage, UserDefaults,
//            Core Data, SwiftData, hoặc file storage

// ❌ PITFALL 5: Complex types không compile
//    @SceneStorage("items") var items: [String] = []  // ❌ Compile error
//    ✅ FIX: Convert qua Data/JSON String (Phần 5)
//            Hoặc dùng CodableSceneState wrapper

// ❌ PITFALL 6: @SceneStorage trong subview không hoạt động đúng
//    Subview bị recreate → @SceneStorage tạo subscription MỚI
//    → Nếu key giống nhau → OK (tự sync)
//    → Nếu key khác → mỗi instance có storage riêng
//    ✅ FIX: Đặt @SceneStorage ở view CHA ổn định,
//            pass xuống con qua @Binding

// ❌ PITFALL 7: Không test trên device thật
//    Simulator KHÔNG reproduce đúng system kill behavior
//    ✅ FIX: Test trên device: chạy app, thay đổi state,
//            mở nhiều app nặng → iOS kill app →
//            mở lại → verify state restoration

// ✅ BEST PRACTICES:
// 1. LIGHTWEIGHT data only: String, Int, Bool, enum, small Data
// 2. UI STATE, không phải user data: tab, scroll, draft, filter
// 3. UNIQUE keys: "featureName_propertyName" convention
// 4. Enum conform RawRepresentable cho type-safe storage
// 5. Convert Codable → Data cho complex types (giữ nhỏ)
// 6. Đặt @SceneStorage ở STABLE parent views
// 7. Kết hợp @SceneStorage (UI state) + @AppStorage (preferences)
// 8. Test trên device: system kill + force quit scenarios
// 9. Không lưu sensitive data (password, tokens) — KHÔNG mã hoá
// 10. Clear scene storage khi user logout:
//     @SceneStorage keys set về default values thủ công
```

---

`@SceneStorage` là property wrapper ít được nói đến nhưng rất quan trọng cho việc khôi phục trạng thái UI khi app bị kill. Mình sẽ giải thích chi tiết cơ chế hoạt động, so sánh với `@AppStorage`, và các production patterns.Mình đã tổng hợp toàn bộ kiến thức `@SceneStorage` trong 9 phần. Đây là những điểm cốt lõi:

**Bản chất của `@SceneStorage`** là khôi phục **UI state** khi iOS kill app ở background rồi user quay lại. Khác hoàn toàn với `@AppStorage` — nó lưu **per-scene** (mỗi window riêng trên iPad) và **không persist sau force quit**.

**Điểm quan trọng nhất — Phần 3: So sánh 3 wrappers:**

| | `@State` | `@SceneStorage` | `@AppStorage` |
|---|---|---|---|
| **Persist** | Không | System kill only | Mãi mãi |
| **Scope** | View instance | Per window/scene | Toàn app |
| **Dùng cho** | UI tạm thời | Tab, scroll, draft | Settings, preferences |

Nguyên tắc chọn đơn giản: User **có chủ đích** lưu giá trị? → `@AppStorage`. Chỉ cần **khôi phục trải nghiệm** sau system kill? → `@SceneStorage`.

**Ba production patterns hay nhất:**

**Phần 7a — Tab + Navigation Restoration**: Lưu `selectedTab`, `searchQuery`, `homeNavID` — khi app restart, user thấy đúng tab, đúng search query, đúng detail screen đang xem. Trải nghiệm liền mạch.

**Phần 7b — Document Editor Draft**: Mỗi iPad window có draft riêng (`doc_title`, `doc_body`, `doc_is_preview`). Window 1 đang edit bài A, window 2 đang preview bài B — cả 2 restore độc lập.

**Phần 7e — Multi-Step Form**: Lưu `currentStep` + data mỗi bước. User đang ở bước 2/3, app bị kill → mở lại → đúng bước 2 với data bước 1 vẫn còn. Không cần nhập lại từ đầu.

**Phần 5c — CodableSceneState wrapper** giải quyết hạn chế lớn nhất: `@SceneStorage` chỉ hỗ trợ primitives. Wrapper này convert Codable ↔ Data cho phép lưu struct/array phức tạp.

**Pitfall #1 quan trọng nhất**: Không lưu data lớn (ảnh, file) — chỉ lưu **ID hoặc path** rồi fetch lại. Scene storage dành cho lightweight state.

Huy muốn mình đi tiếp sang chủ đề nào khác không?
