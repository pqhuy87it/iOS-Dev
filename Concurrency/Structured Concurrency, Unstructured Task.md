```Swift
// ============================================================
// STRUCTURED CONCURRENCY & UNSTRUCTURED TASK TRONG SWIFTUI
// ============================================================
//
// Swift Concurrency có 2 mô hình:
//
// ┌─ STRUCTURED ─────────────────────────────────────────────┐
// │  Child tasks GẮN với parent scope (hàm, .task, TaskGroup)│
// │  → TỰ ĐỘNG cancel khi parent cancel/exit                │
// │  → Parent CHỜI tất cả children hoàn thành                │
// │  → KHÔNG THỂ LEAK — lifecycle quản lý bởi compiler       │
// │                                                           │
// │  Gồm: async let, TaskGroup, .task { }, .task(id:) { }   │
// └───────────────────────────────────────────────────────────┘
//
// ┌─ UNSTRUCTURED ───────────────────────────────────────────┐
// │  Task TÁCH RỜI — không gắn với scope nào                 │
// │  → KHÔNG tự cancel — phải cancel THỦ CÔNG               │
// │  → Có thể sống lâu hơn context tạo ra nó                │
// │  → CÓ THỂ LEAK nếu quên cancel                          │
// │                                                           │
// │  Gồm: Task { }, Task.detached { }                       │
// └───────────────────────────────────────────────────────────┘
//
// SwiftUI tích hợp sâu với Structured Concurrency qua .task.
// Unstructured Task cần khi: button actions, fire-and-forget,
// bridging callback APIs, background work ngoài view lifecycle.
// ============================================================

import SwiftUI


// ╔══════════════════════════════════════════════════════════╗
// ║  PHẦN I — STRUCTURED CONCURRENCY                         ║
// ╚══════════════════════════════════════════════════════════╝


// ╔══════════════════════════════════════════════════════════╗
// ║  1. async let — PARALLEL TASKS CÙNG SCOPE                ║
// ╚══════════════════════════════════════════════════════════╝

// async let tạo child tasks chạy SONG SONG,
// parent scope CHỜI tất cả hoàn thành trước khi exit.

struct AsyncLetDemo: View {
    @State private var profile: UserProfile?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 16) {
            if let profile {
                Text(profile.name).font(.title.bold())
                Text("\(profile.posts.count) posts")
                Text("\(profile.followers) followers")
            }
        }
        .overlay { if isLoading { ProgressView() } }
        .task {
            isLoading = true
            defer { isLoading = false }
            
            // 3 requests chạy SONG SONG — không đợi nhau
            async let name = fetchUserName()
            async let posts = fetchUserPosts()
            async let followers = fetchFollowerCount()
            
            // await TẤT CẢ → tổng hợp kết quả
            // Nếu 1 task fail → các task khác bị CANCEL
            let result = await (name, posts, followers)
            
            profile = UserProfile(
                name: result.0,
                posts: result.1,
                followers: result.2
            )
            
            // STRUCTURED:
            // - 3 child tasks GẮN với .task scope
            // - View disappear → .task cancel → 3 children TỰ CANCEL
            // - KHÔNG THỂ leak — compiler đảm bảo await trước khi exit scope
        }
    }
}

struct UserProfile {
    let name: String
    let posts: [String]
    let followers: Int
}

func fetchUserName() async -> String {
    try? await Task.sleep(for: .seconds(0.5))
    return "Huy Nguyen"
}

func fetchUserPosts() async -> [String] {
    try? await Task.sleep(for: .seconds(1.0))
    return (1...10).map { "Post \($0)" }
}

func fetchFollowerCount() async -> Int {
    try? await Task.sleep(for: .seconds(0.7))
    return 1234
}

// async let LIFECYCLE:
//
// .task {
//     async let a = fetchA()  // ← Child task A bắt đầu NGAY
//     async let b = fetchB()  // ← Child task B bắt đầu NGAY (parallel)
//
//     // ...code khác chạy đồng thời...
//
//     let result = await (a, b)  // ← Chờ CẢ HAI xong
//     // HOẶC: nếu scope EXIT trước await → a, b bị CANCEL
// }
//
// ⚠️ PHẢI await async let TRƯỚC KHI SCOPE EXIT
// Nếu không await → compiler tự thêm implicit cancel + await
// → Child tasks bị cancel ngay lập tức


// === async let với error handling ===

struct AsyncLetErrorDemo: View {
    @State private var result = ""
    
    var body: some View {
        Text(result)
            .task {
                do {
                    async let data = fetchData()
                    async let config = fetchConfig()
                    
                    // Nếu fetchData() throws → fetchConfig() TỰ CANCEL
                    let (d, c) = try await (data, config)
                    result = "Data: \(d), Config: \(c)"
                } catch {
                    result = "Error: \(error.localizedDescription)"
                }
            }
    }
    
    func fetchData() async throws -> String {
        try await Task.sleep(for: .seconds(1))
        return "data"
    }
    
    func fetchConfig() async throws -> String {
        try await Task.sleep(for: .seconds(0.5))
        return "config"
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  2. TaskGroup — DYNAMIC PARALLEL TASKS                    ║
// ╚══════════════════════════════════════════════════════════╝

// async let: số tasks cố định lúc compile-time
// TaskGroup: số tasks DYNAMIC lúc runtime (từ array, loop)

struct TaskGroupDemo: View {
    @State private var images: [String: String] = [:]
    @State private var isLoading = true
    
    let imageIDs = ["img-1", "img-2", "img-3", "img-4", "img-5"]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(imageIDs, id: \.self) { id in
                HStack {
                    Text(id)
                    Spacer()
                    Text(images[id] ?? "...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .overlay { if isLoading { ProgressView() } }
        .task {
            isLoading = true
            defer { isLoading = false }
            
            // === withTaskGroup: N tasks parallel ===
            let results = await withTaskGroup(
                of: (String, String).self  // Return type mỗi child
            ) { group in
                // Thêm child tasks DYNAMICALLY
                for id in imageIDs {
                    group.addTask {
                        // Mỗi child chạy PARALLEL
                        let url = await downloadImage(id: id)
                        return (id, url) // Trả kết quả
                    }
                }
                
                // Thu thập kết quả
                var dict: [String: String] = [:]
                for await (id, url) in group {
                    // Kết quả đến KHÔNG theo thứ tự addTask
                    // Cái nào xong trước → trả trước
                    dict[id] = url
                }
                return dict
            }
            
            images = results
            
            // STRUCTURED:
            // - Tất cả child tasks GẮN trong withTaskGroup scope
            // - withTaskGroup CHỜI tất cả children xong mới return
            // - View disappear → .task cancel → group cancel → ALL children cancel
        }
    }
}

func downloadImage(id: String) async -> String {
    let delay = Double.random(in: 0.3...1.5)
    try? await Task.sleep(for: .seconds(delay))
    return "https://cdn.example.com/\(id).jpg"
}


// === TaskGroup với error handling: withThrowingTaskGroup ===

struct ThrowingTaskGroupDemo: View {
    @State private var results: [String] = []
    @State private var error: String?
    
    var body: some View {
        VStack {
            ForEach(results, id: \.self) { Text($0) }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .task {
            do {
                results = try await withThrowingTaskGroup(
                    of: String.self
                ) { group in
                    for i in 1...5 {
                        group.addTask {
                            try await fetchItem(id: i)
                            // Nếu 1 child throws → group CANCEL tất cả
                        }
                    }
                    
                    var items: [String] = []
                    for try await item in group {
                        items.append(item)
                    }
                    return items
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    func fetchItem(id: Int) async throws -> String {
        try await Task.sleep(for: .milliseconds(Int.random(in: 200...800)))
        if id == 3 && Bool.random() { throw URLError(.badServerResponse) }
        return "Item \(id)"
    }
}


// === TaskGroup với concurrency limit ===

struct LimitedConcurrencyDemo: View {
    @State private var progress = 0
    @State private var total = 20
    
    var body: some View {
        VStack {
            ProgressView(value: Double(progress), total: Double(total))
            Text("\(progress)/\(total)")
        }
        .padding()
        .task {
            let urls = (1...total).map { "item-\($0)" }
            
            await withTaskGroup(of: String.self) { group in
                var iterator = urls.makeIterator()
                let maxConcurrent = 3 // Tối đa 3 cùng lúc
                
                // Khởi tạo batch đầu: 3 tasks
                for _ in 0..<min(maxConcurrent, urls.count) {
                    if let url = iterator.next() {
                        group.addTask { await self.process(url) }
                    }
                }
                
                // Khi 1 task xong → thêm task MỚI (giữ 3 concurrent)
                for await _ in group {
                    progress += 1
                    if let url = iterator.next() {
                        group.addTask { await self.process(url) }
                    }
                }
            }
        }
    }
    
    func process(_ url: String) async -> String {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 300...1000)))
        return "done: \(url)"
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  3. .task { } & .task(id:) — SWIFTUI STRUCTURED          ║
// ╚══════════════════════════════════════════════════════════╝

// .task là Structured Concurrency trong SwiftUI:
// - Task GẮN với view lifecycle
// - Auto-cancel khi view disappear
// - .task(id:) auto-cancel + restart khi id đổi

struct SwiftUITaskDemo: View {
    @State private var category = "tech"
    @State private var items: [String] = []
    
    var body: some View {
        VStack {
            Picker("Category", selection: $category) {
                Text("Tech").tag("tech")
                Text("Design").tag("design")
            }
            .pickerStyle(.segmented)
            
            List(items, id: \.self) { Text($0) }
        }
        // .task(id:) = structured concurrency gắn với view
        .task(id: category) {
            // SEQUENCE:
            // 1. category đổi "tech" → "design"
            // 2. Task cũ ("tech") bị CANCEL
            // 3. Task mới ("design") bắt đầu
            // 4. View disappear → task hiện tại bị CANCEL
            
            items = []
            try? await Task.sleep(for: .seconds(0.5))
            
            // Check cancellation sau mỗi await
            guard !Task.isCancelled else { return }
            
            items = (1...10).map { "\(category) \($0)" }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  PHẦN II — UNSTRUCTURED TASKS                            ║
// ╚══════════════════════════════════════════════════════════╝


// ╔══════════════════════════════════════════════════════════╗
// ║  4. Task { } — UNSTRUCTURED (KẾ THỪA CONTEXT)            ║
// ╚══════════════════════════════════════════════════════════╝

// Task { } tạo task TÁCH RỜI khỏi scope hiện tại,
// nhưng KẾ THỪA: priority, actor context (MainActor), task-local values.

struct UnstructuredTaskDemo: View {
    @State private var status = "Ready"
    @State private var activeTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 16) {
            Text(status)
                .font(.title2)
            
            // === Trong Button action: BẮT BUỘC dùng Task { } ===
            // Vì Button action closure KHÔNG phải async context
            Button("Load Data") {
                // ❌ await fetchData() — KHÔNG compile vì closure không async
                
                // ✅ Task { } tạo async context MỚI
                activeTask = Task {
                    // Kế thừa MainActor từ View context
                    // → có thể update @State trực tiếp
                    status = "Loading..."
                    
                    let data = await fetchData()
                    
                    // ⚠️ Check cancellation — Task { } KHÔNG auto-cancel!
                    guard !Task.isCancelled else {
                        status = "Cancelled"
                        return
                    }
                    
                    status = "Loaded: \(data)"
                }
            }
            
            // Cancel button
            Button("Cancel") {
                activeTask?.cancel() // Phải cancel THỦ CÔNG
                status = "Cancelled"
            }
            .buttonStyle(.bordered)
        }
        .onDisappear {
            // ⚠️ PHẢI cancel khi view disappear — Task { } KHÔNG tự cancel!
            activeTask?.cancel()
        }
    }
    
    func fetchData() async -> String {
        try? await Task.sleep(for: .seconds(2))
        return "Data loaded"
    }
}

// Task { } PROPERTIES:
// ┌──────────────────────────────────────────────────────────┐
// │ KẾ THỪA từ context tạo:                                  │
// │  ✅ Actor context (MainActor nếu trong View)             │
// │  ✅ Task priority                                         │
// │  ✅ Task-local values                                     │
// │                                                           │
// │ KHÔNG kế thừa:                                            │
// │  ❌ Structured cancellation (KHÔNG tự cancel)            │
// │  ❌ Parent-child relationship                             │
// │                                                           │
// │ Lifecycle:                                                │
// │  - Sống INDEPENDENCE — không gắn với scope nào           │
// │  - Phải cancel THỦ CÔNG hoặc chờ hoàn thành              │
// │  - CÓ THỂ LEAK nếu quên cancel                          │
// └──────────────────────────────────────────────────────────┘


// ╔══════════════════════════════════════════════════════════╗
// ║  5. Task.detached { } — HOÀN TOÀN TÁCH RỜI               ║
// ╚══════════════════════════════════════════════════════════╝

// Task.detached KHÔNG kế thừa BẤT CỨ GÌ từ context:
// - KHÔNG kế thừa actor (chạy ngoài MainActor)
// - KHÔNG kế thừa priority
// - KHÔNG kế thừa task-local values

struct DetachedTaskDemo: View {
    @State private var status = "Ready"
    @State private var processedImage: String?
    
    var body: some View {
        VStack(spacing: 16) {
            Text(status)
            
            Button("Process Image") {
                Task {
                    status = "Processing..."
                    
                    // Heavy work NGOÀI MainActor → không block UI
                    let result = await Task.detached(priority: .userInitiated) {
                        // ❌ KHÔNG trên MainActor
                        // ❌ KHÔNG thể update @State trực tiếp ở đây
                        // ✅ CPU-intensive work thoải mái
                        
                        await self.heavyImageProcessing()
                    }.value // .value chờ kết quả
                    
                    // Quay lại MainActor (vì Task { } kế thừa MainActor)
                    processedImage = result
                    status = "Done: \(result)"
                }
            }
        }
    }
    
    // Nonisolated — chạy ở bất kỳ thread
    nonisolated func heavyImageProcessing() async -> String {
        // Simulate heavy CPU work
        try? await Task.sleep(for: .seconds(2))
        return "processed_image.jpg"
    }
}

// Task { } vs Task.detached { }:
// ┌────────────────────────┬────────────────┬──────────────────┐
// │                        │ Task { }       │ Task.detached {} │
// ├────────────────────────┼────────────────┼──────────────────┤
// │ Actor context          │ ✅ Kế thừa    │ ❌ Không         │
// │ (MainActor trong View) │ (MainActor)    │ (nonisolated)    │
// │ Priority               │ ✅ Kế thừa    │ ❌ Phải set      │
// │ Task-local values      │ ✅ Kế thừa    │ ❌ Không         │
// │ Update @State          │ ✅ Trực tiếp  │ ❌ Phải @MainActor│
// │ Heavy CPU work         │ ⚠️ Block Main │ ✅ Off main      │
// │ Auto-cancel            │ ❌ Không      │ ❌ Không         │
// └────────────────────────┴────────────────┴──────────────────┘
//
// 📌 NGUYÊN TẮC:
// Task { }         → Cần MainActor (update UI), fire-and-forget
// Task.detached {} → Heavy CPU work ngoài main thread
// Cả hai            → Phải quản lý cancel THỦ CÔNG


// ╔══════════════════════════════════════════════════════════╗
// ║  6. KHI NÀO DÙNG Task { } TRONG SWIFTUI?                ║
// ╚══════════════════════════════════════════════════════════╝

// Button actions, gesture handlers, onChange — đều SYNC closures.
// Cần Task { } để bridge sang async world.

struct WhenToUseTaskDemo: View {
    @State private var data: [String] = []
    @State private var tasks: [Task<Void, Never>] = []
    
    var body: some View {
        List(data, id: \.self) { Text($0) }
        
        // ✅ USE CASE 1: Button action
        .toolbar {
            Button("Refresh") {
                // Button action KHÔNG async → cần Task { }
                Task { await refresh() }
            }
        }
        
        // ✅ USE CASE 2: onChange (sync closure)
        .onChange(of: data.count) { _, newCount in
            // onChange closure KHÔNG async → cần Task { }
            Task { await logAnalytics("count: \(newCount)") }
        }
        
        // ❌ KHÔNG CẦN Task { } trong .task (đã async)
        .task {
            // Đã là async context → dùng await trực tiếp
            data = await fetchItems()
        }
        
        // ❌ KHÔNG CẦN Task { } trong .refreshable (đã async)
        .refreshable {
            await refresh()
        }
        
        // Cleanup
        .onDisappear {
            tasks.forEach { $0.cancel() }
        }
    }
    
    func refresh() async {
        try? await Task.sleep(for: .seconds(1))
        data.insert("New item", at: 0)
    }
    
    func fetchItems() async -> [String] {
        try? await Task.sleep(for: .seconds(0.5))
        return (1...10).map { "Item \($0)" }
    }
    
    func logAnalytics(_ event: String) async {
        // Send to analytics server
    }
}

// DECISION TABLE:
// ┌──────────────────────────────┬─────────────────────────────┐
// │ Context                      │ Cách dùng async             │
// ├──────────────────────────────┼─────────────────────────────┤
// │ .task { }                    │ ✅ await trực tiếp          │
// │ .task(id:) { }              │ ✅ await trực tiếp          │
// │ .refreshable { }             │ ✅ await trực tiếp          │
// │ Button action { }            │ Task { await ... }          │
// │ .onChange(of:) { }           │ Task { await ... }          │
// │ .onAppear { }                │ Task { await ... }          │
// │                              │ ⚠️ Prefer .task thay thế   │
// │ .onSubmit { }                │ Task { await ... }          │
// │ .onTapGesture { }            │ Task { await ... }          │
// │ Gesture .onChanged { }       │ Task { await ... }          │
// │ Timer callback                │ Task { await ... }          │
// │ NotificationCenter callback  │ Task { await ... }          │
// └──────────────────────────────┴─────────────────────────────┘


// ╔══════════════════════════════════════════════════════════╗
// ║  7. TASK CANCELLATION — CƠ CHẾ HUỶ TASK                  ║
// ╚══════════════════════════════════════════════════════════╝

// Swift Concurrency dùng COOPERATIVE cancellation:
// Cancel = set FLAG, task phải TỰ CHECK và exit.

struct CancellationDemo: View {
    @State private var progress = 0.0
    @State private var status = "Idle"
    @State private var downloadTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
            Text(status)
            
            HStack(spacing: 16) {
                Button("Start") { startDownload() }
                    .disabled(downloadTask != nil)
                
                Button("Cancel") { cancelDownload() }
                    .disabled(downloadTask == nil)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .onDisappear { cancelDownload() }
    }
    
    func startDownload() {
        progress = 0
        status = "Downloading..."
        
        downloadTask = Task {
            for i in 1...100 {
                // === CÁCH 1: Check Task.isCancelled ===
                guard !Task.isCancelled else {
                    status = "Cancelled at \(i)%"
                    return
                }
                
                // === CÁCH 2: try Task.checkCancellation() ===
                // throws CancellationError nếu đã cancelled
                // do {
                //     try Task.checkCancellation()
                // } catch {
                //     status = "Cancelled"
                //     return
                // }
                
                // Simulate work
                try? await Task.sleep(for: .milliseconds(50))
                // Task.sleep TỰ ĐỘNG throw khi cancelled!
                
                progress = Double(i) / 100.0
            }
            
            status = "Complete!"
            downloadTask = nil
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()  // Set cancel flag
        downloadTask = nil
    }
}

// CANCELLATION METHODS:
//
// 1. Task.isCancelled (property)
//    → Check flag, return Bool. KHÔNG throw.
//    guard !Task.isCancelled else { return }
//
// 2. Task.checkCancellation() (throws)
//    → Throw CancellationError nếu cancelled.
//    try Task.checkCancellation()
//
// 3. Task.sleep() (tự throw khi cancelled)
//    → CancellationError thrown tự động.
//
// 4. withTaskCancellationHandler { } onCancel: { }
//    → Chạy cleanup code KHI cancel flag được set.
//
// ⚠️ Cancellation là COOPERATIVE:
// .cancel() chỉ SET FLAG — task KHÔNG bị kill ngay.
// Task phải CHECK flag và TỰ EXIT.
// Nếu task không check → chạy mãi dù đã cancelled.


// === withTaskCancellationHandler ===

struct CancellationHandlerDemo: View {
    @State private var status = "Ready"
    
    var body: some View {
        Text(status)
            .task {
                status = "Working..."
                
                await withTaskCancellationHandler {
                    // Main operation
                    try? await Task.sleep(for: .seconds(10))
                    status = "Done"
                } onCancel: {
                    // Chạy NGAY LẬP TỨC khi task bị cancel
                    // ⚠️ Chạy trên THREAD KHÁC — cẩn thận race condition
                    print("🚫 Cancellation handler fired!")
                    // Dùng cho: cancel URLSession, close file handle,
                    // cleanup C resources
                }
            }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  8. TASK PRIORITY                                        ║
// ╚══════════════════════════════════════════════════════════╝

struct TaskPriorityDemo: View {
    var body: some View {
        VStack(spacing: 12) {
            // Structured: priority kế thừa từ .task
            Text("Structured Tasks")
                .task(priority: .high) {
                    // Task này chạy ở priority .high
                    // async let bên trong CŨNG .high (kế thừa)
                    async let a = fetchA()
                    async let b = fetchB()
                    _ = await (a, b)
                }
            
            // Unstructured: set priority khi tạo
            Button("Load") {
                // Task { } kế thừa priority từ context
                Task {
                    await fetchA() // Chạy ở priority inherited
                }
                
                // Task cụ thể priority
                Task(priority: .background) {
                    await heavyComputation()
                }
                
                // Detached: phải set explicit
                Task.detached(priority: .utility) {
                    await self.heavyComputation()
                }
            }
        }
    }
    
    func fetchA() async -> String { "A" }
    func fetchB() async -> String { "B" }
    func heavyComputation() async { }
}

// PRIORITY LEVELS (cao → thấp):
// .high / .userInitiated   → UI-blocking work, user đang chờ
// .medium                  → Default
// .low / .utility          → Background work user biết
// .background              → Prefetch, analytics, maintenance
//
// Priority Inversion Protection:
// Nếu high-priority task chờ low-priority task
// → Swift TỰ ĐỘNG nâng priority low task lên tạm thời


// ╔══════════════════════════════════════════════════════════╗
// ║  9. PRODUCTION PATTERNS TRONG SWIFTUI                     ║
// ╚══════════════════════════════════════════════════════════╝

// === 9a. ViewModel với Structured + Unstructured ===

@Observable
final class SearchViewModel {
    var query = ""
    var results: [String] = []
    var isSearching = false
    var error: Error?
    
    // === Structured: gọi từ .task(id:) ===
    func search(_ query: String) async {
        guard !query.isEmpty else {
            results = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        // Debounce
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        
        // Parallel fetch: suggestions + results
        async let suggestions = fetchSuggestions(query)
        async let searchResults = fetchResults(query)
        
        guard !Task.isCancelled else { return }
        
        let (_, items) = await (suggestions, searchResults)
        results = items
    }
    
    // === Unstructured: fire-and-forget analytics ===
    func trackSearch(_ query: String) {
        // KHÔNG cần chờ kết quả → fire-and-forget
        Task(priority: .background) {
            await AnalyticsService.shared.trackEvent("search", query: query)
        }
        // Task tự hoàn thành, không cần cancel
        // Nếu mất cũng không sao (analytics)
    }
    
    private func fetchSuggestions(_ q: String) async -> [String] {
        try? await Task.sleep(for: .seconds(0.3))
        return ["suggest 1", "suggest 2"]
    }
    
    private func fetchResults(_ q: String) async -> [String] {
        try? await Task.sleep(for: .seconds(0.8))
        return (1...10).map { "\(q) result \($0)" }
    }
}

class AnalyticsService {
    static let shared = AnalyticsService()
    func trackEvent(_ name: String, query: String) async {
        try? await Task.sleep(for: .seconds(0.5))
    }
}

struct SearchScreen: View {
    @State private var vm = SearchViewModel()
    
    var body: some View {
        NavigationStack {
            List(vm.results, id: \.self) { Text($0) }
                .searchable(text: $vm.query)
                .overlay {
                    if vm.isSearching { ProgressView() }
                }
        }
        // STRUCTURED: auto-cancel khi query đổi hoặc view disappear
        .task(id: vm.query) {
            await vm.search(vm.query)
        }
        // UNSTRUCTURED: fire-and-forget analytics
        .onChange(of: vm.query) { _, newQuery in
            vm.trackSearch(newQuery)
        }
    }
}


// === 9b. Image Batch Processor ===

@Observable
final class ImageProcessor {
    var progress: Double = 0
    var processedCount = 0
    var totalCount = 0
    var isProcessing = false
    private var processingTask: Task<[String], Never>?
    
    // Unstructured: gọi từ Button action
    func startBatchProcessing(images: [String]) {
        processingTask?.cancel()
        
        totalCount = images.count
        processedCount = 0
        isProcessing = true
        
        processingTask = Task {
            defer {
                isProcessing = false
                processingTask = nil
            }
            
            // STRUCTURED bên trong: TaskGroup parallel processing
            let results = await withTaskGroup(of: String.self) { group in
                var processed: [String] = []
                var iterator = images.makeIterator()
                let maxConcurrent = 4
                
                for _ in 0..<min(maxConcurrent, images.count) {
                    if let img = iterator.next() {
                        group.addTask { await self.processImage(img) }
                    }
                }
                
                for await result in group {
                    processed.append(result)
                    processedCount += 1
                    progress = Double(processedCount) / Double(totalCount)
                    
                    if let img = iterator.next() {
                        group.addTask { await self.processImage(img) }
                    }
                }
                
                return processed
            }
            
            return results
        }
    }
    
    func cancel() {
        processingTask?.cancel()
    }
    
    private func processImage(_ name: String) async -> String {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 200...800)))
        return "processed_\(name)"
    }
}


// === 9c. Debounced Search (Structured) ===

struct DebouncedSearchView: View {
    @State private var query = ""
    @State private var results: [String] = []
    
    var body: some View {
        List(results, id: \.self) { Text($0) }
            .searchable(text: $query)
            .task(id: query) {
                // task(id:) cancel task cũ khi query đổi
                // → built-in debounce behavior!
                
                // Thêm delay → debounce thực sự
                try? await Task.sleep(for: .milliseconds(400))
                
                // Nếu query đổi nữa trong 400ms:
                // → task này bị cancel → sleep throws → exit
                // → task MỚI bắt đầu với query mới
                guard !Task.isCancelled else { return }
                
                results = await searchAPI(query)
            }
    }
    
    func searchAPI(_ q: String) async -> [String] {
        guard !q.isEmpty else { return [] }
        try? await Task.sleep(for: .seconds(0.5))
        return (1...5).map { "\(q) result \($0)" }
    }
}


// === 9d. Timeout Pattern ===

struct TimeoutDemo: View {
    @State private var result = ""
    
    var body: some View {
        Text(result)
            .task {
                do {
                    result = try await withTimeout(seconds: 3) {
                        await slowFetch()
                    }
                } catch is TimeoutError {
                    result = "Timeout!"
                } catch {
                    result = "Error: \(error)"
                }
            }
    }
    
    func slowFetch() async -> String {
        try? await Task.sleep(for: .seconds(5))
        return "Data"
    }
}

struct TimeoutError: Error {}

func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Task 1: operation thực
        group.addTask {
            try await operation()
        }
        
        // Task 2: timeout timer
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        
        // Cái nào xong TRƯỚC → trả kết quả, CANCEL cái còn lại
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  10. TỔNG HỢP COMPARISON                                 ║
// ╚══════════════════════════════════════════════════════════╝

// ┌───────────────────┬──────────────┬──────────────┬──────────────┬──────────────┐
// │                   │ async let    │ TaskGroup    │ Task { }     │ Task.detached│
// ├───────────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
// │ Type              │ Structured   │ Structured   │ Unstructured │ Unstructured │
// │ Auto-cancel       │ ✅ Scope exit│ ✅ Scope exit│ ❌ Manual    │ ❌ Manual    │
// │ Inherits actor    │ ✅           │ ✅           │ ✅           │ ❌           │
// │ Inherits priority │ ✅           │ ✅           │ ✅           │ ❌           │
// │ # of children     │ Fixed        │ Dynamic      │ 1            │ 1            │
// │ Parent waits      │ ✅ Implicit  │ ✅ Explicit  │ ❌           │ ❌           │
// │ Can outlive scope │ ❌           │ ❌           │ ✅           │ ✅           │
// │ Return value      │ ✅ Via await │ ✅ Via group │ ✅ .value    │ ✅ .value    │
// │ Leak possible     │ ❌           │ ❌           │ ✅           │ ✅           │
// │ Dùng cho          │ Fixed parallel│ Dynamic     │ Button, onChange│ Heavy CPU  │
// │                   │ fetch        │ batch process│ fire-forget  │ off main     │
// └───────────────────┴──────────────┴──────────────┴──────────────┴──────────────┘


// ╔══════════════════════════════════════════════════════════╗
// ║  11. COMMON PITFALLS & BEST PRACTICES                    ║
// ╚══════════════════════════════════════════════════════════╝

// ❌ PITFALL 1: Task { } trong .onAppear không cancel
//    .onAppear { Task { await longWork() } }
//    → View disappear nhưng task VẪN CHẠY → leak, crash
//    ✅ FIX: .task { await longWork() } — auto-cancel

// ❌ PITFALL 2: Quên check Task.isCancelled
//    Task { for i in 0..<1000000 { process(i) } }
//    → Sau cancel, vẫn process 1 triệu items
//    ✅ FIX: Check isCancelled TRONG loop + SAU mỗi await

// ❌ PITFALL 3: Task.detached update UI trực tiếp
//    Task.detached { self.status = "Done" }
//    → Chạy ngoài MainActor → race condition, crash
//    ✅ FIX: await MainActor.run { self.status = "Done" }
//            Hoặc dùng Task { } thay Task.detached

// ❌ PITFALL 4: async let không await → implicit cancel
//    func load() async {
//        async let data = fetch()  // Bắt đầu
//        return                     // Exit scope → data bị CANCEL!
//    }
//    ✅ FIX: let result = await data trước khi exit

// ❌ PITFALL 5: TaskGroup kết quả KHÔNG theo thứ tự
//    for await result in group { results.append(result) }
//    → Thứ tự = cái nào XONG TRƯỚC, không phải thứ tự addTask
//    ✅ FIX: Trả về (index, value) nếu cần giữ thứ tự

// ❌ PITFALL 6: Unbounded TaskGroup → DDoS
//    for url in thousandURLs { group.addTask { fetch(url) } }
//    → 1000 requests CÙNG LÚC → server/network quá tải
//    ✅ FIX: Limit concurrency pattern (Phần 2)

// ❌ PITFALL 7: Task { } trong ForEach / List row
//    ForEach(items) { item in
//        Text(item.name).onAppear { Task { await fetch(item) } }
//    }
//    → Scroll nhanh → hàng trăm Tasks không cancel
//    ✅ FIX: Dùng .task { } trên row view (auto-cancel khi scroll out)

// ✅ BEST PRACTICES:
// 1. PREFER Structured (.task, async let, TaskGroup) → auto-cancel
// 2. Task { } CHỈ KHI: Button action, onChange, callback bridge
// 3. Task.detached CHỈ KHI: heavy CPU work ngoài main thread
// 4. Lưu Task reference + cancel trong .onDisappear nếu dùng Task { }
// 5. LUÔN check Task.isCancelled sau mỗi await + trong loops
// 6. .task(id:) cho debounced search — built-in cancel + restart
// 7. TaskGroup + iterator cho concurrency limit
// 8. async let cho fixed parallel fetches (2-5 requests)
// 9. TaskGroup cho dynamic parallel (array of URLs, batch process)
// 10. withTaskCancellationHandler cho cleanup C/system resources
// 11. Priority: .userInitiated cho UI, .background cho analytics
// 12. withTimeout pattern cho network requests có deadline
```

---

Đây là chủ đề nền tảng của Swift Concurrency — hiểu đúng Structured vs Unstructured quyết định cách viết async code an toàn, không leak, không crash trong SwiftUI. Mình sẽ giải thích toàn bộ.Mình đã tổng hợp toàn bộ kiến thức Structured Concurrency và Unstructured Tasks trong 11 phần. Đây là bức tranh toàn cảnh:

**Khác biệt cốt lõi** nằm ở **lifecycle management**: Structured tasks (async let, TaskGroup, .task) **tự động cancel** khi parent scope exit — compiler đảm bảo không thể leak. Unstructured tasks (Task { }, Task.detached) sống **độc lập** — phải cancel thủ công, có thể leak nếu quên.

**Năm phần giá trị nhất:**

**Phần 1 — async let**: Parallel fetching cố định (2-5 requests) với syntax đẹp nhất. Điểm then chốt: nếu 1 child task throws → tất cả siblings **tự động cancel**. Và nếu scope exit trước await → compiler **implicit cancel** tất cả children. Không thể leak.

**Phần 2 — TaskGroup + Concurrency Limit**: Pattern quan trọng nhất cho production — batch processing N items với giới hạn concurrent (ví dụ 3 requests cùng lúc thay vì 1000). Dùng iterator pattern: khởi tạo 3 tasks, mỗi khi 1 xong → thêm 1 mới, giữ đúng 3 concurrent luôn.

**Phần 5 — Task { } vs Task.detached**: `Task { }` **kế thừa MainActor** từ View context → update @State trực tiếp. `Task.detached` **không kế thừa gì** → chạy ngoài main thread, phải `await MainActor.run { }` để update UI. Dùng `Task.detached` chỉ khi cần heavy CPU work tránh block main thread.

**Phần 6 — Decision Table**: Bảng tra nhanh — `.task { }`, `.refreshable { }` đã là async → await trực tiếp. Button action, `.onChange`, `.onAppear` là sync closures → cần `Task { await ... }`. Đây là nguồn confusion lớn nhất cho developers mới.

**Phần 9d — Timeout Pattern**: Dùng `withThrowingTaskGroup` + 2 child tasks (operation + timer) — cái nào xong trước thắng, cái còn lại bị cancel. Pattern cực kỳ hữu ích cho network requests có deadline mà Swift chưa có built-in.

**Pitfall #7 quan trọng nhất**: `Task { }` trong `.onAppear` của LazyVStack rows → scroll nhanh tạo **hàng trăm tasks không cancel**. Fix: dùng `.task { }` modifier trên row view → auto-cancel khi row scroll out of viewport.

Huy muốn mình đi tiếp sang chủ đề nào khác không?
