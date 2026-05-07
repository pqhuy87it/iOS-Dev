```Swift
// ============================================================
// BGTASKSCHEDULER TRONG SWIFTUI — GIẢI THÍCH CHI TIẾT
// ============================================================
//
// BGTaskScheduler (BackgroundTasks framework, iOS 13+) cho phép
// app ĐĂNG KÝ công việc để iOS chạy khi app ở BACKGROUND.
//
// iOS QUYẾT ĐỊNH khi nào chạy — không phải app quyết định.
// iOS xem xét: battery, network, user patterns, system load...
//
// 2 loại Background Tasks:
//
// ┌─ BGAppRefreshTask ───────────────────────────────────────┐
// │  Thời gian: ~30 giây                                     │
// │  Tần suất: iOS quyết định (thường vài giờ/lần)           │
// │  Dùng cho: refresh data, sync nhẹ, update widget         │
// │  Ví dụ: fetch tin mới, check notifications, sync settings│
// └──────────────────────────────────────────────────────────┘
//
// ┌─ BGProcessingTask ───────────────────────────────────────┐
// │  Thời gian: vài phút (lên đến ~10 phút)                 │
// │  Tần suất: khi device idle, charging, WiFi              │
// │  Dùng cho: heavy work, database cleanup, ML training     │
// │  Ví dụ: Core Data migration, image processing, backup    │
// └──────────────────────────────────────────────────────────┘
//
// ⚠️ QUAN TRỌNG:
// - iOS KHÔNG đảm bảo task sẽ chạy — chỉ "best effort"
// - iOS có thể KILL task bất kỳ lúc nào (expiration handler)
// - User tắt Background App Refresh → task KHÔNG chạy
// - App PHẢI handle task bị cancel gracefully
// ============================================================

import BackgroundTasks
import SwiftUI


// ╔══════════════════════════════════════════════════════════╗
// ║  1. SETUP — CẤU HÌNH PROJECT                             ║
// ╚══════════════════════════════════════════════════════════╝

// === BƯỚC 1: Info.plist — Khai báo task identifiers ===
//
// Info.plist > Permitted background task scheduler identifiers
// (Key: BGTaskSchedulerPermittedIdentifiers)
//
// <key>BGTaskSchedulerPermittedIdentifiers</key>
// <array>
//     <string>com.myapp.refresh</string>
//     <string>com.myapp.db-cleanup</string>
//     <string>com.myapp.sync</string>
//     <string>com.myapp.processing</string>
// </array>
//
// ⚠️ PHẢI khai báo TẤT CẢ task identifiers ở đây.
// Quên → runtime crash khi register.

// === BƯỚC 2: Capabilities ===
// Xcode > Target > Signing & Capabilities > + Background Modes
// ✅ Check: "Background fetch"
// ✅ Check: "Background processing"

// === BƯỚC 3: Task Identifiers — Constants ===

enum BackgroundTaskID {
    static let appRefresh = "com.myapp.refresh"
    static let dbCleanup = "com.myapp.db-cleanup"
    static let dataSync = "com.myapp.sync"
    static let heavyProcessing = "com.myapp.processing"
}


// ╔══════════════════════════════════════════════════════════╗
// ║  2. ĐĂNG KÝ TASK HANDLERS — App Launch                   ║
// ╚══════════════════════════════════════════════════════════╝

// Task handlers PHẢI đăng ký TRƯỚC app finish launching.
// Trong SwiftUI: @main App init hoặc AppDelegate.

// === Cách 1: SwiftUI App struct ===

@main
struct MyApp: App {
    
    // AppDelegate adapter cho background tasks
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // ═══ ĐĂNG KÝ TẤT CẢ TASK HANDLERS ═══
        // PHẢI gọi TRƯỚC khi app finish launching!
        
        registerBackgroundTasks()
        
        return true
    }
    
    private func registerBackgroundTasks() {
        
        // === 2a. App Refresh Task ===
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.appRefresh,
            using: nil  // nil = main queue. Hoặc custom DispatchQueue
        ) { task in
            // Handler: iOS gọi khi đến lúc chạy task
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
        
        // === 2b. Database Cleanup (Processing) ===
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.dbCleanup,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleDatabaseCleanup(task: processingTask)
        }
        
        // === 2c. Data Sync (Processing) ===
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.dataSync,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleDataSync(task: processingTask)
        }
        
        // === 2d. Heavy Processing ===
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.heavyProcessing,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleHeavyProcessing(task: processingTask)
        }
    }
    
    
    // ╔══════════════════════════════════════════════════════╗
    // ║  3. TASK HANDLERS — XỬ LÝ CÔNG VIỆC                  ║
    // ╚══════════════════════════════════════════════════════╝
    
    // === 3a. App Refresh Handler (~30 giây) ===
    
    private func handleAppRefresh(task: BGAppRefreshTask) {
        
        // ① ĐẶT LỊCH cho LẦN SAU ngay lập tức
        // (Nếu quên → task chỉ chạy 1 lần duy nhất!)
        scheduleAppRefresh()
        
        // ② Tạo async work
        let refreshOperation = Task {
            do {
                // Fetch new data
                let newArticles = try await APIService.shared.fetchLatestArticles()
                
                // Save to local database
                await DatabaseManager.shared.saveArticles(newArticles)
                
                // Update app badge
                await MainActor.run {
                    UNUserNotificationCenter.current()
                        .setBadgeCount(newArticles.count)
                }
                
                // Update widgets
                // WidgetCenter.shared.reloadAllTimelines()
                
                // ✅ BÁO iOS: task HOÀN THÀNH THÀNH CÔNG
                task.setTaskCompleted(success: true)
                
            } catch {
                // ❌ BÁO iOS: task THẤT BẠI
                task.setTaskCompleted(success: false)
                // success: false → iOS có thể retry sớm hơn
            }
        }
        
        // ③ EXPIRATION HANDLER — iOS sắp kill task
        task.expirationHandler = {
            // iOS gọi khi HẾT THỜI GIAN (~30s)
            // PHẢI cleanup + setTaskCompleted ngay!
            refreshOperation.cancel()
            // Nếu KHÔNG gọi setTaskCompleted → iOS có thể
            // throttle future tasks (phạt app)
            task.setTaskCompleted(success: false)
        }
    }
    
    
    // === 3b. Database Cleanup Handler (vài phút) ===
    
    private func handleDatabaseCleanup(task: BGProcessingTask) {
        
        // Schedule cho lần sau
        scheduleDatabaseCleanup()
        
        let cleanupOperation = Task {
            do {
                // Heavy work: xoá records cũ, compact database
                let deletedCount = try await DatabaseManager.shared.deleteOldRecords(
                    olderThan: Date.now.addingTimeInterval(-30 * 24 * 3600) // 30 ngày
                )
                
                // Compact database
                try await DatabaseManager.shared.vacuum()
                
                // Clear image cache > 100MB
                await CacheManager.shared.pruneCache(maxSizeMB: 100)
                
                print("✅ Cleanup done: deleted \(deletedCount) records")
                task.setTaskCompleted(success: true)
                
            } catch {
                print("❌ Cleanup failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            cleanupOperation.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    
    // === 3c. Data Sync Handler ===
    
    private func handleDataSync(task: BGProcessingTask) {
        
        scheduleDataSync()
        
        let syncOperation = Task {
            do {
                // Upload pending changes
                let pendingItems = await DatabaseManager.shared.getPendingSync()
                
                for item in pendingItems {
                    // Check cancellation mỗi iteration
                    guard !Task.isCancelled else { break }
                    
                    try await APIService.shared.syncItem(item)
                    await DatabaseManager.shared.markSynced(item.id)
                }
                
                // Download remote changes
                let remoteChanges = try await APIService.shared.fetchChanges(
                    since: UserDefaults.standard.object(forKey: "last_sync") as? Date ?? .distantPast
                )
                await DatabaseManager.shared.applyChanges(remoteChanges)
                
                UserDefaults.standard.set(Date.now, forKey: "last_sync")
                
                task.setTaskCompleted(success: true)
                
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            syncOperation.cancel()
            // Save progress: items đã sync KHÔNG cần sync lại
            task.setTaskCompleted(success: false)
        }
    }
    
    
    // === 3d. Heavy Processing Handler ===
    
    private func handleHeavyProcessing(task: BGProcessingTask) {
        
        let processingOperation = Task {
            do {
                // ML model update
                // try await MLModelManager.shared.updateModels()
                
                // Image compression batch
                // try await ImageProcessor.shared.compressPendingImages()
                
                // Analytics aggregation
                // try await AnalyticsManager.shared.aggregateEvents()
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            processingOperation.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    
    // ╔══════════════════════════════════════════════════════╗
    // ║  4. SCHEDULE TASKS — ĐẶT LỊCH                        ║
    // ╚══════════════════════════════════════════════════════╝
    
    // === 4a. Schedule App Refresh ===
    
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: BackgroundTaskID.appRefresh
        )
        
        // Không chạy trước thời điểm này
        // nil = chạy SỚM NHẤT có thể
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        // → Không sớm hơn 15 phút nữa
        // iOS có thể chạy SAU thời điểm này tùy điều kiện
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 App refresh scheduled")
        } catch BGTaskScheduler.Error.notPermitted {
            print("❌ Background refresh not permitted (user disabled?)")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            print("❌ Too many pending requests (max 10)")
        } catch BGTaskScheduler.Error.unavailable {
            print("❌ Background tasks unavailable on this device")
        } catch {
            print("❌ Schedule failed: \(error)")
        }
    }
    
    // === 4b. Schedule Processing Task ===
    
    func scheduleDatabaseCleanup() {
        let request = BGProcessingTaskRequest(
            identifier: BackgroundTaskID.dbCleanup
        )
        
        // Chỉ chạy khi: device charging + có WiFi
        request.requiresNetworkConnectivity = false // Cleanup không cần mạng
        request.requiresExternalPower = true        // Chỉ khi đang sạc
        
        // Chạy không sớm hơn 1 giờ nữa
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Cleanup schedule failed: \(error)")
        }
    }
    
    func scheduleDataSync() {
        let request = BGProcessingTaskRequest(
            identifier: BackgroundTaskID.dataSync
        )
        
        request.requiresNetworkConnectivity = true  // Cần mạng để sync
        request.requiresExternalPower = false        // Chạy cả khi pin
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ Sync schedule failed: \(error)")
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  5. KHI NÀO ĐẶT LỊCH (SCHEDULE) TASKS?                  ║
// ╚══════════════════════════════════════════════════════════╝

// Schedule tasks tại CÁC THỜI ĐIỂM QUAN TRỌNG:

struct SchedulingStrategy {
    
    // ① App vào BACKGROUND → schedule refresh
    // Trong ScenePhase observation:
    static func onEnterBackground() {
        let delegate = UIApplication.shared.delegate as? AppDelegate
        delegate?.scheduleAppRefresh()
        delegate?.scheduleDataSync()
    }
    
    // ② Sau khi task hoàn thành → schedule TASK TIẾP THEO
    // (Đã làm trong mỗi handler ở Phần 3)
    
    // ③ Khi user thay đổi settings
    static func onSettingsChanged() {
        // Re-schedule với tần suất mới
        // Ví dụ: user bật/tắt auto-sync
    }
    
    // ④ App launch → schedule nếu chưa có pending
    static func onAppLaunch() {
        BGTaskScheduler.shared.getPendingTaskRequests { requests in
            let hasRefresh = requests.contains { $0.identifier == BackgroundTaskID.appRefresh }
            if !hasRefresh {
                let delegate = UIApplication.shared.delegate as? AppDelegate
                delegate?.scheduleAppRefresh()
            }
        }
    }
}

// === Tích hợp với SwiftUI scenePhase ===

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView {
            Text("Home").tabItem { Label("Home", systemImage: "house") }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // App vào background → schedule tasks
                SchedulingStrategy.onEnterBackground()
                
            case .active:
                // App trở lại foreground → check & display updated data
                break
                
            default:
                break
            }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  6. DEBUG & TESTING — SIMULATE BACKGROUND TASKS           ║
// ╚══════════════════════════════════════════════════════════╝

// iOS KHÔNG cho phép trigger background tasks theo ý muốn.
// Nhưng Xcode cung cấp công cụ simulate.

// === 6a. Xcode Debug Console Commands ===
//
// Trong khi app đang chạy trên Simulator/Device:
//
// Pause app (⌘\), rồi gõ trong LLDB console:
//
// e -l objc -- (void)[[BGTaskScheduler sharedScheduler]
//   _simulateLaunchForTaskWithIdentifier:@"com.myapp.refresh"]
//
// → iOS NGAY LẬP TỨC chạy handler cho task đó
// → App PHẢI đang BACKGROUND (nhấn Home trước)

// === 6b. Launch argument simulate ===
// Scheme > Run > Arguments > Launch Arguments:
// -com.apple.BackgroundTaskScheduler.developerMode 1
//
// → Giảm thời gian chờ giữa các task requests (debug only)

// === 6c. Testing strategy ===

struct BackgroundTaskTests {
    
    // Unit test handler logic (KHÔNG cần BGTask thật)
    static func testRefreshLogic() async {
        // Extract logic ra function testable:
        let articles = try? await APIService.shared.fetchLatestArticles()
        assert(articles != nil, "Should fetch articles")
    }
    
    // Integration test: dùng mock
    static func testHandlerWithMock() async {
        let mockService = MockAPIService()
        mockService.mockArticles = [
            // ... mock data
        ]
        
        // Test logic trực tiếp, KHÔNG qua BGTaskScheduler
        let articles = try? await mockService.fetchLatestArticles()
        assert(articles?.count == 5)
    }
}

// === 6d. Verify task đã schedule ===

func debugPendingTasks() {
    BGTaskScheduler.shared.getPendingTaskRequests { requests in
        print("📋 Pending tasks (\(requests.count)):")
        for request in requests {
            print("  - \(request.identifier)")
            print("    earliest: \(request.earliestBeginDate?.formatted() ?? "ASAP")")
        }
    }
}

// === 6e. Cancel all pending tasks ===

func cancelAllBackgroundTasks() {
    BGTaskScheduler.shared.cancelAllTaskRequests()
    print("🚫 All background tasks cancelled")
}

func cancelSpecificTask(_ identifier: String) {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
}


// ╔══════════════════════════════════════════════════════════╗
// ║  7. PRODUCTION PATTERNS                                   ║
// ╚══════════════════════════════════════════════════════════╝

// === 7a. BackgroundTaskManager — Centralized Management ===

@Observable
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private(set) var lastRefreshDate: Date?
    private(set) var lastSyncDate: Date?
    private(set) var lastCleanupDate: Date?
    private(set) var pendingTaskCount = 0
    
    private let defaults = UserDefaults.standard
    
    private init() {
        lastRefreshDate = defaults.object(forKey: "bg_last_refresh") as? Date
        lastSyncDate = defaults.object(forKey: "bg_last_sync") as? Date
        lastCleanupDate = defaults.object(forKey: "bg_last_cleanup") as? Date
    }
    
    // ─── Register All Handlers ───
    
    func registerAllTasks() {
        registerRefreshTask()
        registerSyncTask()
        registerCleanupTask()
    }
    
    private func registerRefreshTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.appRefresh,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else { return }
            self?.performRefresh(task: task)
        }
    }
    
    private func registerSyncTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.dataSync,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            self?.performSync(task: task)
        }
    }
    
    private func registerCleanupTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskID.dbCleanup,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else { return }
            self?.performCleanup(task: task)
        }
    }
    
    // ─── Schedule Methods ───
    
    func scheduleRefresh(afterMinutes: Double = 15) {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskID.appRefresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: afterMinutes * 60)
        submitRequest(request)
    }
    
    func scheduleSync(afterMinutes: Double = 30) {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskID.dataSync)
        request.earliestBeginDate = Date(timeIntervalSinceNow: afterMinutes * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        submitRequest(request)
    }
    
    func scheduleCleanup(afterHours: Double = 24) {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskID.dbCleanup)
        request.earliestBeginDate = Date(timeIntervalSinceNow: afterHours * 3600)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        submitRequest(request)
    }
    
    func scheduleAllOnBackground() {
        scheduleRefresh()
        scheduleSync()
        // Cleanup: chỉ schedule nếu chưa chạy > 24h
        if needsCleanup() { scheduleCleanup() }
    }
    
    private func submitRequest(_ request: BGTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("❌ BGTask schedule error: \(error)")
        }
        updatePendingCount()
    }
    
    // ─── Task Execution ───
    
    private func performRefresh(task: BGAppRefreshTask) {
        // Schedule next NGAY
        scheduleRefresh()
        
        let operation = Task { @MainActor in
            do {
                // Lightweight fetch — ~30 seconds max
                let newData = try await APIService.shared.fetchLatestArticles()
                await DatabaseManager.shared.saveArticles(newData)
                
                // Notify UI nếu app foreground
                NotificationCenter.default.post(
                    name: .backgroundRefreshCompleted,
                    object: nil,
                    userInfo: ["count": newData.count]
                )
                
                self.lastRefreshDate = .now
                self.defaults.set(Date.now, forKey: "bg_last_refresh")
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            operation.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    private func performSync(task: BGProcessingTask) {
        scheduleSync()
        
        let operation = Task {
            do {
                // Incremental sync with progress tracking
                let pending = await DatabaseManager.shared.getPendingSync()
                var syncedCount = 0
                
                for item in pending {
                    guard !Task.isCancelled else { break }
                    try await APIService.shared.syncItem(item)
                    await DatabaseManager.shared.markSynced(item.id)
                    syncedCount += 1
                }
                
                await MainActor.run {
                    self.lastSyncDate = .now
                    self.defaults.set(Date.now, forKey: "bg_last_sync")
                }
                
                // Thành công nếu sync PHẦN hoặc toàn bộ
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            operation.cancel()
            // Incremental: items đã sync thì KHÔNG cần sync lại
            task.setTaskCompleted(success: false)
        }
    }
    
    private func performCleanup(task: BGProcessingTask) {
        let operation = Task {
            do {
                try await DatabaseManager.shared.deleteOldRecords(
                    olderThan: Date.now.addingTimeInterval(-30 * 24 * 3600)
                )
                try await DatabaseManager.shared.vacuum()
                await CacheManager.shared.pruneCache(maxSizeMB: 100)
                
                await MainActor.run {
                    self.lastCleanupDate = .now
                    self.defaults.set(Date.now, forKey: "bg_last_cleanup")
                }
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            operation.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    // ─── Helpers ───
    
    func needsCleanup() -> Bool {
        guard let last = lastCleanupDate else { return true }
        return Date.now.timeIntervalSince(last) > 24 * 3600
    }
    
    func updatePendingCount() {
        BGTaskScheduler.shared.getPendingTaskRequests { [weak self] requests in
            DispatchQueue.main.async {
                self?.pendingTaskCount = requests.count
            }
        }
    }
}

// Notification name
extension Notification.Name {
    static let backgroundRefreshCompleted = Notification.Name("backgroundRefreshCompleted")
}


// === 7b. AppDelegate sử dụng Manager ===

class ProductionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskManager.shared.registerAllTasks()
        return true
    }
}


// === 7c. View hiển thị background task status ===

struct BackgroundTaskStatusView: View {
    let manager = BackgroundTaskManager.shared
    
    var body: some View {
        Form {
            Section("Background Tasks") {
                StatusRow(
                    title: "Data Refresh",
                    lastRun: manager.lastRefreshDate,
                    icon: "arrow.clockwise"
                )
                StatusRow(
                    title: "Data Sync",
                    lastRun: manager.lastSyncDate,
                    icon: "arrow.triangle.2.circlepath"
                )
                StatusRow(
                    title: "Cleanup",
                    lastRun: manager.lastCleanupDate,
                    icon: "trash"
                )
            }
            
            Section {
                Text("Pending tasks: \(manager.pendingTaskCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Force Schedule All") {
                    manager.scheduleAllOnBackground()
                }
                
                Button("Cancel All Tasks", role: .destructive) {
                    cancelAllBackgroundTasks()
                }
            }
        }
        .onAppear { manager.updatePendingCount() }
    }
}

struct StatusRow: View {
    let title: String
    let lastRun: Date?
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                if let lastRun {
                    Text("Lần cuối: \(lastRun, style: .relative) trước")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Chưa chạy")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}


// === 7d. Widget Timeline Refresh ===

/*
import WidgetKit

private func performRefreshForWidget(task: BGAppRefreshTask) {
    scheduleRefresh()
    
    let operation = Task {
        do {
            let data = try await APIService.shared.fetchWidgetData()
            
            // Lưu vào App Group shared defaults
            let shared = UserDefaults(suiteName: "group.com.myapp.shared")
            shared?.setCodable(data, forKey: "widget_data")
            
            // Trigger widget reload
            WidgetCenter.shared.reloadAllTimelines()
            
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }
    
    task.expirationHandler = {
        operation.cancel()
        task.setTaskCompleted(success: false)
    }
}
*/


// === 7e. Local Notification khi refresh xong ===

/*
import UserNotifications

private func notifyUserOfNewContent(count: Int) {
    guard count > 0 else { return }
    
    let content = UNMutableNotificationContent()
    content.title = "Nội dung mới"
    content.body = "\(count) bài viết mới đã được cập nhật."
    content.sound = .default
    content.badge = NSNumber(value: count)
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(
        identifier: "new_content_\(Date.now.timeIntervalSince1970)",
        content: content,
        trigger: trigger
    )
    
    UNUserNotificationCenter.current().add(request)
}
*/


// ╔══════════════════════════════════════════════════════════╗
// ║  8. HANDLE TASK EXECUTION FLOW — CHI TIẾT                 ║
// ╚══════════════════════════════════════════════════════════╝

// Task execution FLOW chi tiết:
//
// ┌──────────────────────────────────────────────────────────┐
// │  1. App schedule task (submit request)                    │
// │  2. App vào background                                   │
// │  3. iOS QUYẾT ĐỊNH khi nào chạy (battery, wifi, idle...) │
// │  4. iOS WAKE UP app process (nếu bị kill trước đó)       │
// │  5. iOS gọi handler closure đã register                  │
// │  6. Handler thực hiện công việc                          │
// │  7. PHẢI gọi setTaskCompleted(success:) khi xong         │
// │                                                          │
// │  ⚠️ Nếu quá thời gian:                                  │
// │  → iOS gọi expirationHandler                             │
// │  → Handler PHẢI cancel work + setTaskCompleted ngay      │
// │                                                          │
// │  ⚠️ Nếu KHÔNG gọi setTaskCompleted:                     │
// │  → iOS có thể THROTTLE future tasks (phạt app)          │
// │  → App mất quyền background execution                    │
// └──────────────────────────────────────────────────────────┘

// CRITICAL RULES:
// 1. LUÔN gọi setTaskCompleted — cả success và failure
// 2. LUÔN implement expirationHandler
// 3. LUÔN schedule TASK TIẾP THEO trong handler
// 4. LUÔN check Task.isCancelled trong loops
// 5. Work phải INCREMENTAL — save progress để resume sau
// 6. KHÔNG dựa vào timing — iOS quyết định khi nào chạy


// ╔══════════════════════════════════════════════════════════╗
// ║  9. iOS SCHEDULING FACTORS — iOS QUYẾT ĐỊNH NHƯ THẾ NÀO? ║
// ╚══════════════════════════════════════════════════════════╝

// iOS cân nhắc các yếu tố sau để quyết định CHẠY task:
//
// ┌─────────────────────────────────────────────────────────┐
// │ Factor                    │ Impact                      │
// ├───────────────────────────┼─────────────────────────────┤
// │ Battery level             │ Thấp → ít chạy hơn         │
// │ Charging state            │ Đang sạc → ưu tiên chạy    │
// │ Network availability      │ WiFi → ưu tiên hơn cellular│
// │ User usage patterns       │ User hay mở app lúc 8AM    │
// │                           │ → refresh trước 8AM        │
// │ Device idle state         │ Đang ngủ, không dùng → chạy│
// │ System load               │ Nhiều app cần BG → ít cơ hội│
// │ Low Power Mode            │ ON → rất hạn chế BG tasks  │
// │ App usage frequency       │ App ít dùng → ít BG tasks  │
// │ requiresExternalPower     │ true → chỉ khi charging    │
// │ requiresNetworkConnectivity│ true → chỉ khi có mạng   │
// │ earliestBeginDate         │ Không chạy trước thời điểm │
// └───────────────────────────┴─────────────────────────────┘
//
// ⚠️ iOS KHÔNG ĐẢM BẢO task sẽ chạy!
// Task có thể bị delay hàng giờ hoặc KHÔNG chạy (rare cases).
// App KHÔNG được dựa vào BG task cho critical functionality.


// ╔══════════════════════════════════════════════════════════╗
// ║  10. COMMON PITFALLS & BEST PRACTICES                    ║
// ╚══════════════════════════════════════════════════════════╝

// ❌ PITFALL 1: Quên khai báo identifier trong Info.plist
//    BGTaskScheduler.register(...) → CRASH: identifier not permitted
//    ✅ FIX: Thêm TẤT CẢ identifiers vào BGTaskSchedulerPermittedIdentifiers

// ❌ PITFALL 2: Register HANDLERS sau app finish launching
//    Handler phải register TRƯỚC didFinishLaunchingWithOptions return
//    ✅ FIX: Register trong AppDelegate.didFinishLaunching hoặc App.init

// ❌ PITFALL 3: Quên gọi setTaskCompleted
//    → iOS THROTTLE future tasks — app mất quyền BG
//    ✅ FIX: LUÔN gọi trong success, failure, VÀ expirationHandler

// ❌ PITFALL 4: Quên schedule task tiếp theo
//    Handler chạy 1 lần → không schedule → KHÔNG BAO GIỜ chạy lại
//    ✅ FIX: Schedule NEXT task ĐẦU TIÊN trong handler (trước work)

// ❌ PITFALL 5: Không implement expirationHandler
//    iOS kill task → cleanup không chạy → data corrupt
//    ✅ FIX: LUÔN implement — cancel work + setTaskCompleted

// ❌ PITFALL 6: Non-incremental work
//    Process 1000 items → iOS kill giữa chừng → mất progress
//    ✅ FIX: Save progress sau MỖI item → resume từ chỗ dừng

// ❌ PITFALL 7: Quá nhiều pending task requests
//    submit() > 10 pending requests → BGTaskScheduler.Error.tooManyPendingTaskRequests
//    ✅ FIX: Tối đa 1 pending request mỗi identifier
//            Cancel cũ trước khi submit mới (nếu cần thay đổi timing)

// ❌ PITFALL 8: Test chỉ trên Simulator
//    Simulator KHÔNG simulate đúng BG scheduling behavior
//    ✅ FIX: Test trên DEVICE THẬT
//            Dùng LLDB _simulateLaunchForTaskWithIdentifier cho debug

// ❌ PITFALL 9: Dựa vào BG task cho critical features
//    "User data auto-save" CHỈ qua BG task → data loss nếu task ko chạy
//    ✅ FIX: BG task = BONUS, không phải REQUIREMENT
//            Save data ngay trong app (foreground) + BG task cho sync

// ❌ PITFALL 10: Background fetch bị user tắt
//    Settings > General > Background App Refresh > OFF
//    → App KHÔNG nhận BG tasks
//    ✅ FIX: Graceful degradation — app vẫn hoạt động
//            Hiện UI hint: "Bật Background Refresh để nhận data mới"

// ✅ BEST PRACTICES:
// 1. Register handlers trong didFinishLaunchingWithOptions
// 2. Schedule khi app vào background (scenePhase == .background)
// 3. LUÔN setTaskCompleted — success + failure + expiration
// 4. LUÔN schedule NEXT task trong handler
// 5. LUÔN implement expirationHandler — cancel + complete
// 6. Incremental work — save progress, resume từ checkpoint
// 7. BGAppRefreshTask (~30s) cho lightweight fetch
// 8. BGProcessingTask (vài phút) cho heavy work, cần charging/WiFi
// 9. Test trên device thật, dùng LLDB simulate
// 10. Centralized BackgroundTaskManager cho clean architecture
// 11. Notify user qua local notification khi có content mới
// 12. Widget timeline refresh kết hợp BG task
// 13. Track last run dates cho debug + scheduling decisions
// 14. BG tasks là BONUS — app phải hoạt động tốt khi không có BG
```

BGTaskScheduler là API duy nhất của Apple để thực hiện công việc khi app ở BACKGROUND — từ refresh data, sync, cleanup đến heavy processing. Mình sẽ giải thích toàn bộ từ setup, configuration đến production patterns.
