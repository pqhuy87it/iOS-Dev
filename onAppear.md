```Swift
// ============================================================
// .onAppear TRONG SWIFTUI — GIẢI THÍCH CHI TIẾT
// ============================================================
// .onAppear là lifecycle modifier — closure được gọi khi view
// SẮP HIỂN THỊ trên màn hình (trước khi user nhìn thấy).
//
// Tương đương viewWillAppear / viewDidAppear trong UIKit
// (timing gần viewWillAppear hơn).
//
// Hệ sinh thái lifecycle modifiers:
// - .onAppear { }           — View sắp hiển thị (iOS 13+)
// - .onDisappear { }        — View sắp biến mất (iOS 13+)
// - .task { }               — Async work khi appear (iOS 15+)
// - .task(id:) { }          — Async work + restart khi id đổi
// - .onChange(of:) { }      — Giá trị thay đổi (iOS 14+)
// ============================================================

import SwiftUI


// ╔══════════════════════════════════════════════════════════╗
// ║  1. CÚ PHÁP CƠ BẢN & TIMING                            ║
// ╚══════════════════════════════════════════════════════════╝

struct BasicOnAppearDemo: View {
    @State private var message = "Chưa appear"
    @State private var log: [String] = []
    
    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.title2.bold())
            
            ForEach(log, id: \.self) { entry in
                Text(entry)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        // === Cú pháp ===
        .onAppear {
            // Closure chạy trên MAIN THREAD
            // Timing: TRƯỚC khi view hiển thị trên màn hình
            message = "Đã appear!"
            log.append("[\(timestamp)] onAppear fired")
        }
        .onDisappear {
            log.append("[\(timestamp)] onDisappear fired")
        }
    }
    
    var timestamp: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: .now)
    }
}

// TIMING CHI TIẾT:
//
// ┌──────────────────────────────────────────────────┐
// │ SwiftUI View Lifecycle                           │
// │                                                  │
// │ 1. View struct init (body computed)              │
// │ 2. SwiftUI tạo rendering tree                   │
// │ 3. ▶ .onAppear fires ← ĐÂY                     │
// │ 4. View render lên màn hình                      │
// │ 5. User thấy view                                │
// │ ...                                              │
// │ 6. View sắp bị remove khỏi hierarchy            │
// │ 7. ▶ .onDisappear fires ← ĐÂY                   │
// │ 8. View biến mất                                  │
// └──────────────────────────────────────────────────┘
//
// ⚠️ QUAN TRỌNG:
// - .onAppear chạy TRÊN MAIN THREAD (synchronous)
// - KHÔNG block rendering — nhưng heavy work sẽ gây LAG
// - Có thể fire NHIỀU LẦN cho cùng 1 view (xem Phần 3)


// ╔══════════════════════════════════════════════════════════╗
// ║  2. CÁC USE CASES PHỔ BIẾN                              ║
// ╚══════════════════════════════════════════════════════════╝

// === 2a. Load data lần đầu ===

struct LoadDataOnAppear: View {
    @State private var items: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        List(items, id: \.self) { item in
            Text(item)
        }
        .overlay {
            if isLoading { ProgressView() }
        }
        .onAppear {
            // Guard: chỉ load nếu chưa có data
            guard items.isEmpty else { return }
            loadData()
        }
    }
    
    func loadData() {
        isLoading = true
        // ⚠️ Synchronous work ở đây!
        // Nếu cần async → dùng Task { } hoặc .task (Phần 5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            items = (1...20).map { "Item \($0)" }
            isLoading = false
        }
    }
}

// === 2b. Analytics tracking ===

struct AnalyticsOnAppear: View {
    let screenName: String
    
    var body: some View {
        Text("Screen: \(screenName)")
            .onAppear {
                // Track screen view
                AnalyticsService.shared.trackScreenView(screenName)
            }
            .onDisappear {
                // Track screen exit
                AnalyticsService.shared.trackScreenExit(screenName)
            }
    }
}

class AnalyticsService {
    static let shared = AnalyticsService()
    func trackScreenView(_ name: String) { print("📊 View: \(name)") }
    func trackScreenExit(_ name: String) { print("📊 Exit: \(name)") }
}

// === 2c. Trigger animation khi view xuất hiện ===

struct AnimateOnAppear: View {
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
                .scaleEffect(isVisible ? 1.0 : 0.3)
                .opacity(isVisible ? 1.0 : 0)
            
            Text("Welcome!")
                .font(.title.bold())
                .offset(y: isVisible ? 0 : 30)
                .opacity(isVisible ? 1.0 : 0)
        }
        .onAppear {
            // Animate sau khi view appear
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                isVisible = true
            }
        }
        .onDisappear {
            // Reset cho lần appear tiếp theo
            isVisible = false
        }
    }
}

// === 2d. Start timer / observer ===

struct TimerOnAppear: View {
    @State private var seconds = 0
    @State private var timer: Timer?
    
    var body: some View {
        Text("Time: \(seconds)s")
            .font(.title.monospaced())
            .onAppear {
                // Start timer khi view appear
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    seconds += 1
                }
            }
            .onDisappear {
                // PHẢI cleanup khi disappear — tránh memory leak
                timer?.invalidate()
                timer = nil
            }
    }
}

// === 2e. Auto-focus TextField ===

struct AutoFocusOnAppear: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField("Search...", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .onAppear {
                // Delay nhỏ để view render xong rồi mới focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
    }
}

// === 2f. Scroll to position ===

struct ScrollOnAppear: View {
    let items = (0..<100).map { "Item \($0)" }
    let scrollToID: Int
    
    var body: some View {
        ScrollViewReader { proxy in
            List(0..<100, id: \.self) { i in
                Text("Item \(i)").id(i)
            }
            .onAppear {
                // Scroll đến item cụ thể khi view appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo(scrollToID, anchor: .center)
                    }
                }
            }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  3. KHI NÀO .onAppear FIRE NHIỀU LẦN?                   ║
// ╚══════════════════════════════════════════════════════════╝

// ⚠️ .onAppear CÓ THỂ fire NHIỀU LẦN cho cùng 1 view.
// Đây là nguồn bugs phổ biến nhất.

// === 3a. Tab switching ===
struct TabAppearDemo: View {
    var body: some View {
        TabView {
            TabContent(name: "Home")
                .tabItem { Text("Home") }
            
            TabContent(name: "Search")
                .tabItem { Text("Search") }
        }
    }
}

struct TabContent: View {
    let name: String
    @State private var appearCount = 0
    
    var body: some View {
        Text("\(name): appeared \(appearCount) times")
            .onAppear {
                appearCount += 1
                print("📱 \(name) onAppear #\(appearCount)")
            }
        // Home → Search → Home → Search
        // Home: onAppear #1, #2, #3 (MỖI LẦN chuyển lại tab)
        // Search: onAppear #1, #2, #3
    }
}

// === 3b. Navigation push/pop ===
// Push B → B.onAppear fires
// Pop B → A.onAppear fires LẠI (A reappear)

// === 3c. Sheet present/dismiss ===
// Present sheet → parent KHÔNG onDisappear (vẫn visible phía sau)
// Dismiss sheet → parent KHÔNG onAppear lại (nó chưa disappear)
// ⚠️ KHÁC VỚI UIKit: viewWillAppear fire khi dismiss modal

// === 3d. ScrollView + LazyVStack ===
// Scroll item ra khỏi viewport → onDisappear
// Scroll lại → onAppear FIRE LẠI
struct LazyAppearDemo: View {
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0..<100) { i in
                    Text("Row \(i)")
                        .onAppear {
                            // Fire MỖI LẦN row scroll vào viewport
                            // KHÔNG CHỈ lần đầu!
                            print("Row \(i) appeared")
                        }
                        .onDisappear {
                            print("Row \(i) disappeared")
                        }
                }
            }
        }
    }
}

// === 3e. Conditional views (if/else) ===
struct ConditionalAppearDemo: View {
    @State private var showDetail = false
    
    var body: some View {
        VStack {
            Button("Toggle") { showDetail.toggle() }
            
            if showDetail {
                Text("Detail")
                    .onAppear {
                        // Fire MỖI LẦN showDetail chuyển true
                        // Vì if/else DESTROY và CREATE view mới
                        print("Detail appeared")
                    }
            }
        }
    }
}

// TÓM TẮT KHI NÀO FIRE LẠI:
// ┌────────────────────────┬───────────┬──────────────┐
// │ Tình huống             │ onAppear  │ onDisappear  │
// ├────────────────────────┼───────────┼──────────────┤
// │ View lần đầu render    │ ✅ 1 lần │              │
// │ Tab switch (đi rồi về) │ ✅ Lại   │ ✅           │
// │ Navigation pop back    │ ✅ Lại   │              │
// │ Sheet dismiss          │ ❌ Không  │ ❌           │
// │   (parent vẫn visible) │           │              │
// │ LazyVStack scroll in   │ ✅ Lại   │ ✅ scroll out│
// │ if/else toggle         │ ✅ Mới   │ ✅ destroy   │
// │ App background→active  │ ❌ Không  │ ❌           │
// └────────────────────────┴───────────┴──────────────┘


// ╔══════════════════════════════════════════════════════════╗
// ║  4. GUARD PATTERNS — CHẠY 1 LẦN DUY NHẤT                ║
// ╚══════════════════════════════════════════════════════════╝

// Khi cần onAppear CHỈ fire 1 lần (init data, analytics first view...)

// === 4a. Guard với @State flag ===

struct OnceOnlyDemo: View {
    @State private var hasAppeared = false
    @State private var data: [String] = []
    
    var body: some View {
        List(data, id: \.self) { Text($0) }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                
                // Chỉ chạy LẦN ĐẦU TIÊN
                loadData()
                trackFirstView()
            }
    }
    
    func loadData() { data = (1...10).map { "Item \($0)" } }
    func trackFirstView() { print("📊 First view") }
}

// === 4b. Guard với data check ===

struct DataGuardDemo: View {
    @State private var items: [String] = []
    
    var body: some View {
        List(items, id: \.self) { Text($0) }
            .onAppear {
                // Chỉ load nếu CHƯA CÓ data
                guard items.isEmpty else { return }
                items = (1...10).map { "Item \($0)" }
            }
        // Tab switch: onAppear fire lại nhưng items đã có → skip
    }
}

// === 4c. Reusable modifier — .onFirstAppear ===

struct OnFirstAppearModifier: ViewModifier {
    @State private var hasAppeared = false
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

extension View {
    func onFirstAppear(perform action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }
}

// Sử dụng:
struct OnFirstAppearUsage: View {
    var body: some View {
        Text("Hello")
            .onFirstAppear {
                // Chạy ĐÚNG 1 LẦN duy nhất
                print("First and only appear!")
            }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  5. .task vs .onAppear — SO SÁNH CHI TIẾT               ║
// ╚══════════════════════════════════════════════════════════╝

// .task (iOS 15+) là evolution của .onAppear cho async work.
// Apple KHUYẾN KHÍCH dùng .task thay .onAppear cho async operations.

// ┌──────────────────────┬───────────────────┬───────────────────┐
// │                      │ .onAppear         │ .task             │
// ├──────────────────────┼───────────────────┼───────────────────┤
// │ Min iOS              │ 13                │ 15                │
// │ Closure type         │ () -> Void        │ () async -> Void  │
// │                      │ (synchronous)     │ (async)           │
// │ await support        │ ❌ Phải wrap      │ ✅ Trực tiếp     │
// │                      │ trong Task { }    │                   │
// │ Auto cancel          │ ❌ Phải thủ công  │ ✅ Khi disappear  │
// │ Thread               │ Main              │ Main (có thể hop) │
// │ Chạy khi             │ View appear       │ View appear       │
// │ task(id:) restart    │ ❌ Không có       │ ✅ Khi id thay đổi│
// │ Multiple calls       │ Mỗi appear        │ Mỗi appear        │
// │ Dùng cho             │ Sync work, setup  │ Async work, fetch │
// └──────────────────────┴───────────────────┴───────────────────┘

// === 5a. ❌ onAppear + Task (cách CŨ) ===

struct OldAsyncPattern: View {
    @State private var data: [String] = []
    @State private var task: Task<Void, Never>?
    
    var body: some View {
        List(data, id: \.self) { Text($0) }
            .onAppear {
                // Phải wrap async trong Task
                task = Task {
                    await loadData()
                }
            }
            .onDisappear {
                // Phải THỦU CÔNG cancel khi disappear
                // Nếu quên → task chạy tiếp dù view đã biến mất
                task?.cancel()
            }
    }
    
    func loadData() async {
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return } // Check cancellation
        data = (1...20).map { "Item \($0)" }
    }
}

// === 5b. ✅ .task (cách MỚI — khuyến khích) ===

struct NewAsyncPattern: View {
    @State private var data: [String] = []
    
    var body: some View {
        List(data, id: \.self) { Text($0) }
            .task {
                // ✅ Trực tiếp await — không cần wrap Task { }
                // ✅ TỰ ĐỘNG cancel khi view disappear
                // ✅ Check Task.isCancelled tự động
                await loadData()
            }
    }
    
    func loadData() async {
        try? await Task.sleep(for: .seconds(1))
        data = (1...20).map { "Item \($0)" }
    }
}

// === 5c. .task(id:) — Restart khi dependency thay đổi ===

struct TaskIDDemo: View {
    @State private var selectedCategory = "all"
    @State private var items: [String] = []
    @State private var isLoading = false
    
    let categories = ["all", "tech", "design", "business"]
    
    var body: some View {
        VStack {
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            List(items, id: \.self) { Text($0) }
                .overlay { if isLoading { ProgressView() } }
        }
        .task(id: selectedCategory) {
            // Fire khi:
            // 1. View appear (lần đầu)
            // 2. selectedCategory THAY ĐỔI (cancel task cũ, start mới)
            
            isLoading = true
            // Task cũ TỰ ĐỘNG bị cancel khi selectedCategory đổi
            try? await Task.sleep(for: .seconds(0.5))
            
            // Check cancellation sau mỗi await point
            guard !Task.isCancelled else { return }
            
            items = (1...10).map { "\(selectedCategory) - Item \($0)" }
            isLoading = false
        }
        // User chọn "tech" → task "all" bị CANCEL
        // → task "tech" bắt đầu
        // Giống .onAppear + .onChange kết hợp, nhưng auto-cancel
    }
}

// === 5d. Khi nào dùng .onAppear vs .task ===

struct WhenToUseWhat: View {
    @State private var data: [String] = []
    @State private var isAnimated = false
    
    var body: some View {
        VStack {
            // ✅ .onAppear: synchronous setup, animations, analytics
            Text("Hello")
                .opacity(isAnimated ? 1 : 0)
                .onAppear {
                    withAnimation(.spring) { isAnimated = true }
                    AnalyticsService.shared.trackScreenView("Home")
                }
            
            // ✅ .task: async data fetching, network calls
            List(data, id: \.self) { Text($0) }
                .task {
                    data = await fetchFromAPI()
                }
        }
    }
    
    func fetchFromAPI() async -> [String] {
        try? await Task.sleep(for: .seconds(1))
        return (1...10).map { "API Item \($0)" }
    }
}

// NGUYÊN TẮC:
// Synchronous (animation, analytics, setup)  → .onAppear
// Asynchronous (network, database, file I/O) → .task
// Async + dependency thay đổi                → .task(id:)


// ╔══════════════════════════════════════════════════════════╗
// ║  6. .onAppear + .onChange COMBINATION                     ║
// ╚══════════════════════════════════════════════════════════╝

// Pattern: load data khi appear + reload khi filter thay đổi

struct AppearPlusChangeDemo: View {
    @State private var items: [String] = []
    @State private var sortOrder = "newest"
    @State private var filter = ""
    
    var body: some View {
        VStack {
            Picker("Sort", selection: $sortOrder) {
                Text("Newest").tag("newest")
                Text("Oldest").tag("oldest")
            }
            .pickerStyle(.segmented)
            
            List(items, id: \.self) { Text($0) }
        }
        // Load ban đầu
        .onAppear {
            guard items.isEmpty else { return }
            loadItems()
        }
        // Reload khi sort thay đổi
        .onChange(of: sortOrder) { _, _ in
            loadItems()
        }
    }
    
    func loadItems() {
        items = (1...10).map { "\(sortOrder) - Item \($0)" }
    }
}

// ✅ CÁCH TỐT HƠN: dùng .task(id:) thay .onAppear + .onChange
struct BetterApproach: View {
    @State private var items: [String] = []
    @State private var sortOrder = "newest"
    
    var body: some View {
        VStack {
            Picker("Sort", selection: $sortOrder) {
                Text("Newest").tag("newest")
                Text("Oldest").tag("oldest")
            }
            .pickerStyle(.segmented)
            
            List(items, id: \.self) { Text($0) }
        }
        .task(id: sortOrder) {
            // 1 modifier thay 2 (.onAppear + .onChange)
            // + auto-cancel task cũ khi sortOrder đổi
            items = await fetchItems(sort: sortOrder)
        }
    }
    
    func fetchItems(sort: String) async -> [String] {
        try? await Task.sleep(for: .milliseconds(300))
        return (1...10).map { "\(sort) - Item \($0)" }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  7. .onAppear TRONG CÁC CONTEXT ĐẶC BIỆT               ║
// ╚══════════════════════════════════════════════════════════╝

// === 7a. Trong LazyVStack — Pagination trigger ===

struct PaginationDemo: View {
    @State private var items = (1...20).map { "Item \($0)" }
    @State private var isLoading = false
    @State private var page = 1
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.gray.opacity(0.05))
                        .onAppear {
                            // Khi item GẦN CUỐI xuất hiện → load thêm
                            if item == items.last {
                                loadMore()
                            }
                        }
                }
                
                if isLoading {
                    ProgressView().padding()
                }
            }
            .padding()
        }
    }
    
    func loadMore() {
        guard !isLoading else { return }
        isLoading = true
        
        // Simulate API delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            page += 1
            let newItems = (1...20).map { "Page \(page) - Item \($0)" }
            items.append(contentsOf: newItems)
            isLoading = false
        }
    }
}

// Threshold-based pagination (tốt hơn):
struct ThresholdPaginationDemo: View {
    @State private var items = (1...30).map { "Item \($0)" }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text(item)
                        .onAppear {
                            // Load khi còn CÁCH CUỐI 5 items
                            if index >= items.count - 5 {
                                loadMore()
                            }
                        }
                }
            }
        }
    }
    
    func loadMore() {
        // Load next page...
    }
}

// === 7b. Trong NavigationStack ===

struct NavigationAppearDemo: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                Text("Root View")
                    .onAppear {
                        print("Root: onAppear")
                        // Fire khi:
                        // 1. Lần đầu render
                        // 2. Pop back từ child (root reappear)
                    }
                
                Button("Push") { path.append("detail") }
            }
            .navigationDestination(for: String.self) { value in
                Text("Detail: \(value)")
                    .onAppear { print("Detail: onAppear") }
                    .onDisappear { print("Detail: onDisappear") }
            }
        }
    }
}

// === 7c. Trong Sheet ===

struct SheetAppearDemo: View {
    @State private var showSheet = false
    
    var body: some View {
        VStack {
            Text("Parent View")
                .onAppear { print("Parent: onAppear") }
                .onDisappear { print("Parent: onDisappear") }
            
            Button("Show Sheet") { showSheet = true }
        }
        .sheet(isPresented: $showSheet) {
            Text("Sheet Content")
                .onAppear { print("Sheet: onAppear") }
                .onDisappear { print("Sheet: onDisappear") }
        }
        // Show sheet:
        //   Sheet: onAppear ✅
        //   Parent: onDisappear ❌ (Parent vẫn visible phía sau!)
        //
        // Dismiss sheet:
        //   Sheet: onDisappear ✅
        //   Parent: onAppear ❌ (Parent chưa từng disappear!)
        //
        // ⚠️ Khác UIKit: viewWillAppear fire khi dismiss modal
    }
}

// === 7d. Trong if/else & ForEach ===

struct ConditionalAppear: View {
    @State private var show = false
    @State private var items = [1, 2, 3]
    
    var body: some View {
        VStack {
            Toggle("Show", isOn: $show)
            
            // if/else: DESTROY + CREATE mới → onAppear fire mỗi lần
            if show {
                Text("Conditional View")
                    .onAppear { print("Conditional: onAppear") }
                    .onDisappear { print("Conditional: onDisappear") }
            }
            
            // ForEach: thêm item mới → onAppear cho item MỚI
            // Item cũ KHÔNG fire lại onAppear
            ForEach(items, id: \.self) { item in
                Text("Item \(item)")
                    .onAppear { print("Item \(item): onAppear") }
            }
            
            Button("Add Item") { items.append(items.count + 1) }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  8. PRODUCTION PATTERNS                                   ║
// ╚══════════════════════════════════════════════════════════╝

// === 8a. ViewModel Integration ===

@Observable
final class ArticleViewModel {
    var articles: [String] = []
    var isLoading = false
    var error: Error?
    private var hasLoaded = false
    
    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        
        isLoading = true
        // Trigger async load...
    }
    
    func loadAsync() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await Task.sleep(for: .seconds(1))
            articles = (1...20).map { "Article \($0)" }
        } catch {
            self.error = error
        }
    }
    
    func refresh() async {
        // Force reload — bypass hasLoaded
        isLoading = true
        defer { isLoading = false }
        
        try? await Task.sleep(for: .seconds(1))
        articles = (1...20).map { "Refreshed \($0)" }
    }
}

struct ArticleListScreen: View {
    @State private var vm = ArticleViewModel()
    
    var body: some View {
        List(vm.articles, id: \.self) { article in
            Text(article)
        }
        .overlay {
            if vm.isLoading && vm.articles.isEmpty { ProgressView() }
        }
        // ✅ Best: .task cho async loading
        .task {
            await vm.loadAsync()
        }
        // Pull-to-refresh (bypass hasLoaded)
        .refreshable {
            await vm.refresh()
        }
    }
}


// === 8b. Impression Tracking (Analytics) ===

struct ImpressionTracker: ViewModifier {
    let itemID: String
    let screenName: String
    @State private var hasTracked = false
    @State private var appearTime: Date?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                appearTime = .now
                // Track impression (lần đầu only)
                if !hasTracked {
                    hasTracked = true
                    AnalyticsService.shared.trackScreenView("\(screenName)_\(itemID)")
                }
            }
            .onDisappear {
                // Track dwell time
                if let start = appearTime {
                    let duration = Date.now.timeIntervalSince(start)
                    print("📊 \(itemID) viewed for \(Int(duration))s")
                }
                appearTime = nil
            }
    }
}

extension View {
    func trackImpression(itemID: String, screen: String) -> some View {
        modifier(ImpressionTracker(itemID: itemID, screenName: screen))
    }
}


// === 8c. Prefetch Pattern (Image/Data) ===

struct PrefetchDemo: View {
    let items: [String]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.gray.opacity(0.05))
                        .onAppear {
                            // Prefetch data cho items SẮP hiển thị
                            prefetchIfNeeded(currentIndex: index)
                        }
                }
            }
        }
    }
    
    func prefetchIfNeeded(currentIndex: Int) {
        // Prefetch 5 items phía trước
        let prefetchRange = (currentIndex + 1)...(currentIndex + 5)
        for i in prefetchRange where i < items.count {
            // Trigger image download, data fetch...
            print("🔮 Prefetching index \(i)")
        }
    }
}


// === 8d. Staggered Animation on Appear ===

struct StaggeredAnimationDemo: View {
    @State private var appeared = Set<Int>()
    let items = Array(0..<10)
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items, id: \.self) { index in
                    HStack {
                        Circle()
                            .fill(.blue.gradient)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading) {
                            Text("Item \(index)").font(.headline)
                            Text("Description").font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.gray.opacity(0.05), in: .rect(cornerRadius: 12))
                    // Staggered animation
                    .opacity(appeared.contains(index) ? 1 : 0)
                    .offset(x: appeared.contains(index) ? 0 : 30)
                    .onAppear {
                        // Delay tăng dần → animation staggered
                        withAnimation(
                            .spring(duration: 0.4)
                            .delay(Double(index) * 0.05)
                        ) {
                            appeared.insert(index)
                        }
                    }
                }
            }
            .padding()
        }
    }
}


// === 8e. Complete Screen Lifecycle ===

struct CompleteLifecycleScreen: View {
    @State private var data: [String] = []
    @State private var isLoading = false
    @State private var animateContent = false
    @Environment(\.scenePhase) private var scenePhase
    
    let screenName = "HomeScreen"
    
    var body: some View {
        List(data, id: \.self) { item in
            Text(item)
                .opacity(animateContent ? 1 : 0)
        }
        
        // 1. Sync setup + animation
        .onAppear {
            // Analytics
            AnalyticsService.shared.trackScreenView(screenName)
            
            // Entry animation
            withAnimation(.easeOut(duration: 0.3)) {
                animateContent = true
            }
        }
        
        // 2. Async data loading
        .task {
            guard data.isEmpty else { return }
            isLoading = true
            data = await fetchData()
            isLoading = false
        }
        
        // 3. Cleanup
        .onDisappear {
            animateContent = false
            AnalyticsService.shared.trackScreenExit(screenName)
        }
        
        // 4. App lifecycle (background → foreground refresh)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshIfStale() }
            }
        }
    }
    
    func fetchData() async -> [String] {
        try? await Task.sleep(for: .seconds(1))
        return (1...20).map { "Item \($0)" }
    }
    
    func refreshIfStale() async {
        // Refresh data nếu đã quá 5 phút
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  9. COMMON PITFALLS & BEST PRACTICES                     ║
// ╚══════════════════════════════════════════════════════════╝

// ❌ PITFALL 1: Async work trong .onAppear không cancel
//    .onAppear { Task { await longRunningWork() } }
//    → View disappear nhưng task VẪN CHẠY → memory leak, crash
//    ✅ FIX: Dùng .task { } → auto-cancel khi disappear
//            Hoặc lưu Task reference + cancel trong .onDisappear

// ❌ PITFALL 2: Expect .onAppear fire 1 lần
//    .onAppear { items = loadFromDB() } // Load LẠI mỗi tab switch!
//    ✅ FIX: guard items.isEmpty hoặc guard !hasLoaded
//            Hoặc dùng .onFirstAppear modifier (Phần 4c)

// ❌ PITFALL 3: Heavy synchronous work trong .onAppear
//    .onAppear { processMillionRecords() } // BLOCK main thread → freeze
//    ✅ FIX: .task { await processInBackground() }
//            Hoặc .onAppear { DispatchQueue.global().async { } }

// ❌ PITFALL 4: Expect .onAppear khi dismiss sheet
//    Parent.onAppear KHÔNG fire khi sheet dismiss
//    Vì parent chưa bao giờ disappear (vẫn visible phía sau sheet)
//    ✅ FIX: Dùng sheet's onDismiss callback:
//            .sheet(isPresented:, onDismiss: { refreshData() })
//            Hoặc .onChange(of: showSheet) { if !$0 { refresh() } }

// ❌ PITFALL 5: .onAppear trong body computed property
//    var body: some View {
//        Text("Hello").onAppear { counter += 1 }
//        // body có thể được compute NHIỀU LẦN (re-render)
//        // nhưng onAppear CHỈ fire khi view APPEAR trên screen
//        // → onAppear KHÔNG fire mỗi lần body recompute ✅
//    }

// ❌ PITFALL 6: Timer/Observer không cleanup trong .onDisappear
//    .onAppear { startTimer() }
//    // Quên .onDisappear { stopTimer() } → timer chạy mãi
//    ✅ FIX: LUÔN pair .onAppear setup với .onDisappear cleanup
//            Hoặc dùng .task { } → auto-cancel

// ❌ PITFALL 7: .onAppear + @FocusState timing
//    .onAppear { isFocused = true } // Đôi khi không work
//    → View chưa render xong → focus không nhận
//    ✅ FIX: DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)
//            Hoặc .task { try? await Task.sleep(for: .milliseconds(300))
//                         isFocused = true }

// ✅ BEST PRACTICES:
// 1. .task cho async work (auto-cancel, cleaner code) — iOS 15+
// 2. .onAppear cho sync work (animation, analytics, setup)
// 3. Guard pattern cho one-time execution
// 4. .onFirstAppear custom modifier cho reusable one-time logic
// 5. .task(id:) thay .onAppear + .onChange combo
// 6. PAIR .onAppear + .onDisappear cho setup/cleanup (timer, observer)
// 7. Threshold-based pagination (5 items trước cuối, không chờ cuối)
// 8. Staggered delay cho appear animations trong LazyVStack
// 9. Đừng expect .onAppear khi sheet dismiss → dùng onDismiss
// 10. Sync setup: .onAppear → Async work: .task → Value change: .onChange
// 11. Test tab switching: verify onAppear logic handle multiple calls
// 12. DispatchQueue.main.asyncAfter cho timing-sensitive setup (focus)
```

---

`.onAppear` là lifecycle modifier cơ bản nhất nhưng có rất nhiều nuances về timing, multiple calls, và đặc biệt là so sánh với `.task` — modifier mà Apple khuyến khích dùng thay thế cho async work. Mình sẽ giải thích toàn bộ.Mình đã tổng hợp toàn bộ kiến thức `.onAppear` trong 9 phần. Đây là những điểm cốt lõi:

**`.onAppear` tưởng đơn giản nhưng có 2 điểm phức tạp** mà rất nhiều developer mắc: nó **fire nhiều lần** (tab switch, navigation pop, LazyVStack scroll), và nó là **synchronous** nên không phù hợp cho async work.

**Ba phần giá trị nhất:**

**Phần 3 — Bảng timing fire/không fire**: Đây là kiến thức quan trọng nhất. Tab switch → fire lại, navigation pop → fire lại, nhưng **sheet dismiss → KHÔNG fire** (vì parent chưa bao giờ disappear — nó vẫn visible phía sau sheet). Đây là khác biệt lớn nhất với UIKit `viewWillAppear`. Bảng trong Phần 3 tóm gọn tất cả scenarios.

**Phần 5 — .task vs .onAppear**: Apple khuyến khích dùng `.task` (iOS 15+) thay `.onAppear` cho async work vì 2 lý do then chốt — `.task` **tự động cancel** khi view disappear (không cần manual cleanup), và `.task(id:)` **thay thế combo** `.onAppear + .onChange` chỉ bằng 1 modifier. Nguyên tắc: sync setup (animation, analytics) → `.onAppear`, async work (fetch, database) → `.task`, async + dependency thay đổi → `.task(id:)`.

**Phần 4c — `.onFirstAppear` modifier**: Reusable modifier giải quyết bài toán "chỉ chạy 1 lần" — wrap `@State hasAppeared` flag trong ViewModifier. Dùng cho: initial data load, first-time analytics, one-time setup. Thay vì copy-paste guard pattern mỗi view.

**Pitfall #4 đáng chú ý nhất**: `.onAppear` **không fire khi dismiss sheet** — vì parent view vẫn visible phía sau sheet, chưa bao giờ "disappear". Fix bằng `onDismiss` callback của `.sheet()` hoặc `.onChange(of: showSheet)`.

Huy muốn mình đi tiếp sang chủ đề nào khác không?
