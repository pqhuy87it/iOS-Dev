# Background Fetch & BGTaskScheduler trong iOS

## 1. Tại sao không thể "Keep App Alive" liên tục?

### iOS App Lifecycle — Thực tế phũ phàng

```
User nhấn Home / switch app:

  ┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐
  │   Active   │────▶│  Inactive  │────▶│ Background │────▶│ Suspended  │
  │            │     │ (transient)│     │  (~5-30s)  │     │  (0% CPU)  │
  │  Full CPU  │     │            │     │ Finish work│     │ Frozen RAM │
  │  Full GPU  │     │            │     │            │     │ Có thể bị  │
  │            │     │            │     │            │     │ kill bất kỳ│
  └────────────┘     └────────────┘     └────────────┘     └────────────┘
                                              │
                                              │ beginBackgroundTask
                                              │ (thêm ~30s nữa)
                                              ▼
                                        ┌────────────┐
                                        │ Extended BG │
                                        │  max ~30s   │
                                        │ Rồi cũng bị │
                                        │  suspend    │
                                        └────────────┘
```

**iOS không cho phép app chạy mãi ở background** (trừ vài ngoại lệ). Đây là thiết kế có chủ đích của Apple để bảo vệ pin, RAM, và thermal.

### Các cách "giữ app sống" và tại sao đều sai

```swift
// ❌ Hack 1: Play silent audio để giữ background mode
let player = AVAudioPlayer()
player.play() // silent audio
// → App Store REJECT, vi phạm guideline 2.5.4
// → Tốn pin vô nghĩa, user phát hiện trong battery settings

// ❌ Hack 2: Fake location updates
locationManager.startUpdatingLocation()
locationManager.allowsBackgroundLocationUpdates = true
// → App Store REJECT nếu app không thực sự cần location
// → Tốn pin khủng khiếp (~20% pin/ngày)
// → iOS 13+ Apple review kỹ hơn, bắt giải thích background location

// ❌ Hack 3: beginBackgroundTask loop
func applicationDidEnterBackground(_ application: UIApplication) {
    var taskID = UIApplication.shared.beginBackgroundTask {
        // Expiration handler
    }
    // Cố gắng request task mới khi task cũ hết hạn
    // → iOS detect và kill app
    // → backgroundTimeRemaining giảm dần về 0
}

// ❌ Hack 4: Liên tục gửi silent push để "đánh thức" app
// → Apple rate-limit silent push
// → Không đảm bảo delivery
// → App bị throttle nặng
```

### Apple cho phép background execution hợp lệ

```
┌──────────────────────────────────────────────────────────────┐
│ Background Mode           │ Thời gian        │ Use case      │
├───────────────────────────┼──────────────────┼───────────────┤
│ beginBackgroundTask       │ ~30 giây          │ Finish upload │
│ Background Fetch (cũ)     │ ~30 giây, hệ     │ Refresh data  │
│                           │ thống schedule    │               │
│ BGAppRefreshTask          │ ~30 giây, thông   │ Refresh data  │
│                           │ minh hơn          │               │
│ BGProcessingTask          │ Vài phút, khi     │ DB cleanup,   │
│                           │ charging + WiFi   │ ML training   │
│ Silent Push               │ ~30 giây          │ New content   │
│ URLSession background     │ Không giới hạn    │ Large upload/ │
│                           │ (system managed)  │ download      │
│ Location updates          │ Liên tục          │ Navigation    │
│ Audio/VoIP                │ Liên tục          │ Music, calls  │
│ Bluetooth                 │ Event-based       │ IoT devices   │
└──────────────────────────────────────────────────────────────┘
```

**BGTaskScheduler (iOS 13+) là cách chính thức và được khuyến nghị** cho hầu hết use case background. Nó thay thế UIApplication `performFetch` cũ.

---

## 2. Background Fetch (Legacy) — Hiểu để migrate

### API cũ (iOS 7-12)

```swift
// AppDelegate — cách cũ, DEPRECATED từ iOS 13

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Yêu cầu hệ thống gọi fetch định kỳ
    application.setMinimumBackgroundFetchInterval(
        UIApplication.backgroundFetchIntervalMinimum
    )
    return true
}

func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    // Hệ thống "đánh thức" app ở background
    // Có ~30 giây để hoàn thành
    
    fetchLatestData { newData in
        if let data = newData {
            self.updateLocalStore(data)
            completionHandler(.newData)      // Có data mới
        } else {
            completionHandler(.noData)       // Không có gì mới
        }
    }
    
    // ⚠️ PHẢI gọi completionHandler, nếu không:
    // → iOS nghĩ app bị treo
    // → Giảm priority cho lần fetch tiếp theo
    // → Cuối cùng không cho fetch nữa
}
```

### Vấn đề của Background Fetch cũ

```
1. Không kiểm soát được thời điểm:
   iOS quyết định KHI NÀO gọi fetch, dựa trên:
   - Tần suất user mở app
   - Battery level
   - Network condition
   - Thermal state
   
   → Có thể 15 phút, có thể vài giờ, có thể KHÔNG BAO GIỜ
   
2. Không phân biệt loại task:
   - Refresh nhẹ (check notification) vs
   - Processing nặng (sync database)
   → Đều cùng API, cùng 30s limit

3. Không phối hợp với system conditions:
   - Không biết device đang charge hay không
   - Không biết có WiFi hay không
```

---

## 3. BGTaskScheduler — Giải pháp hiện đại

### Hai loại task

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  BGAppRefreshTask                BGProcessingTask           │
│  ─────────────────               ──────────────────         │
│  Thời gian: ~30 giây             Thời gian: vài phút       │
│  Tần suất: thường xuyên          Tần suất: ít hơn          │
│  Điều kiện: linh hoạt            Điều kiện: có thể yêu cầu │
│                                  • Device đang charge       │
│                                  • Có WiFi                  │
│  Use case:                       Use case:                  │
│  • Refresh feed                  • Core Data migration      │
│  • Sync nhẹ                      • ML model training        │
│  • Check new messages            • Database cleanup         │
│  • Update widget data            • Large sync               │
│  • Badge count update            • Log upload               │
│                                  • Backup                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Setup hoàn chỉnh

#### Bước 1: Info.plist

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.myapp.refresh.feed</string>
    <string>com.myapp.refresh.messages</string>
    <string>com.myapp.processing.dbcleanup</string>
    <string>com.myapp.processing.sync</string>
</array>
```

Mỗi task identifier phải khai báo ở đây. Thiếu → crash khi register.

#### Bước 2: Capabilities

```
Xcode → Target → Signing & Capabilities → + Background Modes
  ☑ Background fetch
  ☑ Background processing
```

#### Bước 3: Register + Schedule

```swift
// MARK: - Task Registration
// Phải register TRƯỚC khi app finish launching

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        registerBackgroundTasks()
        return true
    }
    
    private func registerBackgroundTasks() {
        // Register HANDLER cho mỗi task identifier
        // Handler được gọi khi iOS "đánh thức" app
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.refresh.feed",
            using: nil  // nil = main queue
        ) { task in
            self.handleFeedRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.myapp.processing.sync",
            using: nil
        ) { task in
            self.handleDatabaseSync(task: task as! BGProcessingTask)
        }
    }
}
```

#### Bước 4: Schedule Tasks

```swift
// MARK: - Task Scheduling
// Schedule KHI NÀO muốn task chạy (thường khi app vào background)

class BackgroundTaskManager {
    
    static let shared = BackgroundTaskManager()
    
    // Gọi khi app vào background
    func scheduleAllTasks() {
        scheduleFeedRefresh()
        scheduleDatabaseSync()
    }
    
    // MARK: - App Refresh Task
    func scheduleFeedRefresh() {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.myapp.refresh.feed"
        )
        
        // Earliest: KHÔNG PHẢI exact time
        // iOS sẽ chạy SAU thời điểm này, khi điều kiện tốt
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 phút
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch BGTaskScheduler.Error.notPermitted {
            // User tắt Background App Refresh trong Settings
            print("Background refresh disabled by user")
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            // Mỗi identifier chỉ có 1 pending request
            // Submit mới sẽ thay thế cái cũ → KHÔNG phải error thực sự
            print("Replaced existing pending request")
        } catch BGTaskScheduler.Error.unavailable {
            // Simulator hoặc device không hỗ trợ
            print("BGTaskScheduler unavailable")
        } catch {
            print("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Processing Task
    func scheduleDatabaseSync() {
        let request = BGProcessingTaskRequest(
            identifier: "com.myapp.processing.sync"
        )
        
        // Processing task có thêm conditions
        request.requiresNetworkConnectivity = true   // Cần network
        request.requiresExternalPower = true          // Cần đang charge
        // ↑ Đặt true cho task tốn pin (ML training, large sync)
        // iOS chỉ chạy khi device đang cắm sạc → user không bị ảnh hưởng
        
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 giờ
        
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

#### Bước 5: Handle Task Execution

```swift
// MARK: - Task Handlers

extension AppDelegate {
    
    func handleFeedRefresh(task: BGAppRefreshTask) {
        // QUAN TRỌNG: Schedule task tiếp theo NGAY LẬP TỨC
        // Nếu không, sẽ không có lần refresh nào nữa
        BackgroundTaskManager.shared.scheduleFeedRefresh()
        
        // Tạo async work
        let operation = Task {
            do {
                let newPosts = try await FeedService.shared.fetchLatestPosts()
                
                if !newPosts.isEmpty {
                    // Update local store
                    await PersistenceManager.shared.save(posts: newPosts)
                    
                    // Update badge
                    await MainActor.run {
                        UNUserNotificationCenter.current()
                            .setBadgeCount(newPosts.count)
                    }
                }
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
                // success: false → iOS có thể retry sớm hơn
            }
        }
        
        // QUAN TRỌNG: Handle expiration
        // iOS có thể cắt thời gian bất kỳ lúc nào
        task.expirationHandler = {
            // Dọn dẹp, cancel work đang chạy
            operation.cancel()
            // Vẫn PHẢI gọi setTaskCompleted
            task.setTaskCompleted(success: false)
        }
    }
    
    func handleDatabaseSync(task: BGProcessingTask) {
        BackgroundTaskManager.shared.scheduleDatabaseSync()
        
        let operation = Task {
            do {
                // Processing task có nhiều thời gian hơn
                // Phù hợp cho batch operations
                
                // Phase 1: Sync pending changes
                let pending = await SyncQueue.shared.pendingChanges()
                for batch in pending.chunked(into: 50) {
                    try Task.checkCancellation()
                    try await APIClient.shared.syncBatch(batch)
                    await SyncQueue.shared.markSynced(batch)
                }
                
                // Phase 2: Cleanup old data
                try Task.checkCancellation()
                await PersistenceManager.shared.deleteOlderThan(days: 30)
                
                // Phase 3: Compact database
                try Task.checkCancellation()
                await PersistenceManager.shared.vacuum()
                
                task.setTaskCompleted(success: true)
            } catch is CancellationError {
                // Bị cancel do expiration → partial work đã lưu
                task.setTaskCompleted(success: false)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            operation.cancel()
            // KHÔNG gọi setTaskCompleted ở đây
            // vì Task catch CancellationError sẽ gọi
        }
    }
}
```

### Scene-based lifecycle (iOS 13+)

```swift
// Với SceneDelegate, schedule khi scene vào background
// KHÔNG phải khi app vào background

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        BackgroundTaskManager.shared.scheduleAllTasks()
    }
}

// Với SwiftUI
@main
struct MyApp: App {
    @Environment(\.scenePhase) var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.shared.scheduleAllTasks()
            }
        }
    }
    
    init() {
        // Register tasks trong init
        registerBackgroundTasks()
    }
}
```

---

## 4. iOS Schedule task như thế nào?

### Hệ thống quyết định — không phải developer

```
Factors iOS cân nhắc khi schedule BGTask:

  ┌─ User Behavior Prediction ────────────────────────────┐
  │                                                        │
  │ iOS học thói quen user:                                │
  │ • User mở app lúc 8AM mỗi ngày                        │
  │   → iOS refresh data lúc ~7:45AM                       │
  │ • User không mở app 3 ngày rồi                         │
  │   → iOS GIẢM tần suất refresh (tiết kiệm pin)         │
  │ • User vừa mở app xong                                │
  │   → Không cần refresh ngay                             │
  │                                                        │
  │ App Score: iOS rate app dựa trên tần suất sử dụng      │
  │ → App ít dùng = ít được background time hơn            │
  └────────────────────────────────────────────────────────┘

  ┌─ Device Conditions ───────────────────────────────────┐
  │                                                        │
  │ • Battery level: < 20% → hạn chế background tasks     │
  │ • Thermal state: .serious/.critical → KHÔNG chạy      │
  │ • Network: WiFi available → ưu tiên tasks cần network │
  │ • Charging: đang charge → chạy processing tasks       │
  │ • Low Power Mode: ON → hạn chế nghiêm ngặt            │
  │ • Storage: gần đầy → ưu tiên cleanup tasks            │
  │                                                        │
  └────────────────────────────────────────────────────────┘

  ┌─ System Load ─────────────────────────────────────────┐
  │                                                        │
  │ • Nhiều app cùng request background time               │
  │   → iOS phải chia sẻ CPU time                          │
  │ • System maintenance đang chạy                         │
  │   (Spotlight indexing, iCloud backup, Photos analysis)  │
  │   → App tasks bị delay                                 │
  │                                                        │
  └────────────────────────────────────────────────────────┘
```

**Hệ quả:** `earliestBeginDate` là **earliest**, không phải exact. Task có thể chạy 5 phút sau, 2 giờ sau, hoặc sáng hôm sau. Developer **không kiểm soát** được thời điểm chính xác.

```swift
// ❌ SAI: nghĩ rằng đây là timer chính xác
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
// "Chạy sau đúng 15 phút" → SAI
// "Chạy sớm nhất là 15 phút nữa, có thể muộn hơn nhiều" → ĐÚNG
```

---

## 5. Silent Push + Background Fetch — Kết hợp

### Khi cần refresh "gần real-time"

BGTask phụ thuộc vào iOS schedule → không đảm bảo timing. Silent push cho phép server **trigger** refresh ngay lập tức.

```
Server-driven refresh:

  Server detect new data
       │
       ▼
  Server ──silent push──▶ APNS ──▶ iOS ──đánh thức app──▶ App
                                                            │
                                         30 giây để fetch data
                                                            │
                                                            ▼
                                                    Update local store
                                                    Update UI (nếu app visible)
                                                    Update widget
```

```swift
// MARK: - Silent Push Handler

func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    // Silent push payload:
    // {
    //   "aps": { "content-available": 1 },
    //   "type": "new_messages",
    //   "conversation_id": "abc123"
    // }
    
    guard let type = userInfo["type"] as? String else {
        completionHandler(.noData)
        return
    }
    
    Task {
        do {
            switch type {
            case "new_messages":
                let conversationID = userInfo["conversation_id"] as? String
                let messages = try await MessageService.shared.fetch(
                    conversationID: conversationID
                )
                
                if messages.isEmpty {
                    completionHandler(.noData)
                } else {
                    await PersistenceManager.shared.save(messages: messages)
                    completionHandler(.newData)
                }
                
            case "content_update":
                try await ContentService.shared.refreshFeed()
                completionHandler(.newData)
                
            default:
                completionHandler(.noData)
            }
        } catch {
            completionHandler(.failed)
        }
    }
    
    // ⚠️ completionHandler PHẢI được gọi trong ~30 giây
    // iOS đo thời gian và tần suất .newData vs .noData
    // Nếu hay trả .noData → iOS giảm priority cho app
}
```

### Silent Push vs BGTaskScheduler — Khi nào dùng gì?

```
┌─────────────────────┬──────────────────┬────────────────────┐
│                     │  Silent Push     │  BGTaskScheduler   │
├─────────────────────┼──────────────────┼────────────────────┤
│ Trigger             │ Server-driven    │ System-scheduled   │
│ Timing              │ Gần real-time    │ Không đảm bảo      │
│ Frequency           │ Rate-limited     │ System quyết định  │
│                     │ bởi APNS         │                    │
│ Cần server setup    │ Có (APNS)        │ Không              │
│ Guaranteed delivery │ Không            │ Không (best effort)│
│ Offline             │ Không            │ Có (scheduled sẵn) │
│ Duration            │ ~30 giây         │ 30s (refresh)      │
│                     │                  │ vài phút (process) │
│ Dùng cho            │ New message      │ Periodic refresh   │
│                     │ Content update   │ DB cleanup         │
│                     │ Data invalidation│ Analytics upload   │
│                     │ Badge update     │ Backup/sync        │
└─────────────────────┴──────────────────┴────────────────────┘
```

---

## 6. Background URLSession — Download/Upload lớn

### Khác biệt hoàn toàn với BGTask

```
BGTask:
  App được "đánh thức" → app code chạy → gọi URLSession → chờ response
  ← Giới hạn thời gian, app phải active

Background URLSession:
  App tạo download task → app bị suspend/kill → HỆ THỐNG download tiếp
  → Download xong → iOS launch lại app → giao data
  ← Không giới hạn thời gian, system daemon xử lý
```

```swift
class BackgroundDownloadManager: NSObject {
    
    static let shared = BackgroundDownloadManager()
    
    private lazy var session: URLSession = {
        // QUAN TRỌNG: identifier phải UNIQUE và CONSISTENT
        // iOS dùng identifier để reconnect session sau khi app bị kill
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.myapp.background.download"
        )
        
        // Cho phép iOS schedule download khi điều kiện tốt
        config.isDiscretionary = true
        // ↑ iOS sẽ chờ WiFi, charging, etc.
        // Tốt cho content pre-fetching, KHÔNG tốt cho user-initiated download
        
        // Cho phép download khi app không chạy
        config.sessionSendsLaunchEvents = true
        
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - Initiate Download
    func downloadFile(from url: URL) -> URLSessionDownloadTask {
        let task = session.downloadTask(with: url)
        
        // Cho download lớn, set earliest begin date
        // → iOS có thể delay đến khi WiFi available
        task.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        
        // Byte count hint giúp iOS estimate thời gian
        task.countOfBytesClientExpectsToSend = 200    // Request size
        task.countOfBytesClientExpectsToReceive = 50_000_000 // 50MB
        
        task.resume()
        return task
    }
}

// MARK: - URLSessionDownloadDelegate
extension BackgroundDownloadManager: URLSessionDownloadDelegate {
    
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // File ở temporary location, PHẢI move ngay
        let destination = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(downloadTask.originalRequest!.url!.lastPathComponent)
        
        try? FileManager.default.moveItem(at: location, to: destination)
    }
    
    // Progress tracking
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        // Update UI nếu app đang foreground
        NotificationCenter.default.post(
            name: .downloadProgress,
            object: nil,
            userInfo: ["progress": progress]
        )
    }
}

// MARK: - AppDelegate: Reconnect sau khi app bị kill rồi launch lại
extension AppDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        // iOS launch lại app để deliver kết quả download
        // Lưu completionHandler, gọi khi xử lý xong TẤT CẢ events
        BackgroundDownloadManager.shared.savedCompletionHandler = completionHandler
    }
}
```

---

## 7. Kết hợp tất cả — Architecture thực tế

### Coordinator pattern

```swift
// MARK: - Central Background Task Coordinator

class BackgroundCoordinator {
    
    static let shared = BackgroundCoordinator()
    
    // MARK: - Task Identifiers
    enum TaskID {
        static let feedRefresh = "com.myapp.refresh.feed"
        static let messageSync = "com.myapp.refresh.messages"
        static let dbMaintenance = "com.myapp.processing.maintenance"
        static let analyticsUpload = "com.myapp.processing.analytics"
    }
    
    // MARK: - Registration (gọi 1 lần khi app launch)
    func registerAll() {
        register(TaskID.feedRefresh) { [weak self] task in
            await self?.refreshFeed(task: task as! BGAppRefreshTask)
        }
        
        register(TaskID.messageSync) { [weak self] task in
            await self?.syncMessages(task: task as! BGAppRefreshTask)
        }
        
        register(TaskID.dbMaintenance) { [weak self] task in
            await self?.performMaintenance(task: task as! BGProcessingTask)
        }
        
        register(TaskID.analyticsUpload) { [weak self] task in
            await self?.uploadAnalytics(task: task as! BGProcessingTask)
        }
    }
    
    private func register(
        _ identifier: String,
        handler: @escaping (BGTask) async -> Void
    ) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            Task { await handler(task) }
        }
    }
    
    // MARK: - Scheduling (gọi khi app vào background)
    func scheduleAll() {
        scheduleRefresh(
            identifier: TaskID.feedRefresh,
            earliestOffset: 15 * 60  // 15 phút
        )
        
        scheduleRefresh(
            identifier: TaskID.messageSync,
            earliestOffset: 5 * 60   // 5 phút
        )
        
        scheduleProcessing(
            identifier: TaskID.dbMaintenance,
            earliestOffset: 2 * 3600,       // 2 giờ
            requiresCharging: true,
            requiresNetwork: false
        )
        
        scheduleProcessing(
            identifier: TaskID.analyticsUpload,
            earliestOffset: 1 * 3600,       // 1 giờ
            requiresCharging: false,
            requiresNetwork: true
        )
    }
    
    private func scheduleRefresh(identifier: String, earliestOffset: TimeInterval) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestOffset)
        try? BGTaskScheduler.shared.submit(request)
    }
    
    private func scheduleProcessing(
        identifier: String,
        earliestOffset: TimeInterval,
        requiresCharging: Bool,
        requiresNetwork: Bool
    ) {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestOffset)
        request.requiresExternalPower = requiresCharging
        request.requiresNetworkConnectivity = requiresNetwork
        try? BGTaskScheduler.shared.submit(request)
    }
    
    // MARK: - Task Handlers
    
    private func refreshFeed(task: BGAppRefreshTask) async {
        // Re-schedule cho lần tiếp theo TRƯỚC KHI làm gì khác
        scheduleRefresh(identifier: TaskID.feedRefresh, earliestOffset: 15 * 60)
        
        let work = Task {
            do {
                let posts = try await FeedService.shared.fetchLatest()
                await PersistenceManager.shared.save(posts: posts)
                
                // Update widget
                WidgetCenter.shared.reloadTimelines(ofKind: "FeedWidget")
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
        
        await work.value
    }
    
    private func syncMessages(task: BGAppRefreshTask) async {
        scheduleRefresh(identifier: TaskID.messageSync, earliestOffset: 5 * 60)
        
        let work = Task {
            do {
                let unread = try await MessageService.shared.syncUnread()
                
                if !unread.isEmpty {
                    await MainActor.run {
                        UNUserNotificationCenter.current()
                            .setBadgeCount(unread.count)
                    }
                }
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
        
        await work.value
    }
    
    private func performMaintenance(task: BGProcessingTask) async {
        scheduleProcessing(
            identifier: TaskID.dbMaintenance,
            earliestOffset: 24 * 3600,
            requiresCharging: true,
            requiresNetwork: false
        )
        
        let work = Task {
            do {
                // Processing task → có nhiều thời gian hơn
                // Checkpoint giữa các bước để resume nếu bị cancel
                
                try Task.checkCancellation()
                await PersistenceManager.shared.deleteExpiredCache()
                
                try Task.checkCancellation()
                await PersistenceManager.shared.rebuildSearchIndex()
                
                try Task.checkCancellation()
                await PersistenceManager.shared.vacuum()
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            work.cancel()
        }
        
        await work.value
    }
    
    private func uploadAnalytics(task: BGProcessingTask) async {
        scheduleProcessing(
            identifier: TaskID.analyticsUpload,
            earliestOffset: 1 * 3600,
            requiresCharging: false,
            requiresNetwork: true
        )
        
        let work = Task {
            do {
                let events = await AnalyticsStore.shared.pendingEvents()
                
                // Upload theo batch, checkpoint sau mỗi batch
                for batch in events.chunked(into: 100) {
                    try Task.checkCancellation()
                    try await AnalyticsAPI.shared.upload(events: batch)
                    await AnalyticsStore.shared.markUploaded(batch)
                }
                
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = { work.cancel() }
        await work.value
    }
}
```

---

## 8. Debug & Test

### Simulate trong Xcode

```
Xcode không thể chờ iOS tự schedule BGTask.
Dùng LLDB command để trigger manually:

1. Launch app
2. Đặt breakpoint trong task handler
3. Pause debugger
4. Chạy trong LLDB console:

e -l objc -- (void)[[BGTaskScheduler sharedScheduler]
    _simulateLaunchForTaskWithIdentifier:
    @"com.myapp.refresh.feed"]

5. Resume → handler được gọi ngay

Hoặc simulate expiration:

e -l objc -- (void)[[BGTaskScheduler sharedScheduler]
    _simulateExpirationForTaskWithIdentifier:
    @"com.myapp.refresh.feed"]
```

### Logging cho production

```swift
import os.log

extension BackgroundCoordinator {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "BackgroundTasks"
    )
    
    func logTaskExecution(identifier: String, duration: TimeInterval, success: Bool) {
        Self.logger.info("""
            BGTask completed: \(identifier)
            Duration: \(duration, format: .fixed(precision: 2))s
            Success: \(success)
            Battery: \(ProcessInfo.processInfo.isBatteryMonitoringEnabled
                ? "\(Int(UIDevice.current.batteryLevel * 100))%"
                : "unknown")
            Thermal: \(ProcessInfo.processInfo.thermalState.rawValue)
        """)
        
        // Gửi metrics về server (lần upload analytics tiếp theo)
        AnalyticsStore.shared.record(event: .backgroundTask(
            identifier: identifier,
            duration: duration,
            success: success
        ))
    }
}
```

---

## 9. Tổng kết — Sai lầm phổ biến & Best Practices

```
┌─ Sai lầm phổ biến ─────────────────────────────────────────┐
│                                                              │
│ ❌ Quên re-schedule task trong handler                       │
│    → Task chỉ chạy 1 lần, không bao giờ chạy lại           │
│                                                              │
│ ❌ Quên gọi setTaskCompleted                                 │
│    → iOS nghĩ app treo, giảm priority vĩnh viễn             │
│                                                              │
│ ❌ Không handle expirationHandler                             │
│    → Work bị kill giữa chừng, data corrupt                   │
│                                                              │
│ ❌ Nghĩ earliestBeginDate là exact timer                     │
│    → Design system dựa trên exact timing → fail              │
│                                                              │
│ ❌ Dùng BGTask cho user-initiated download                   │
│    → Quá chậm, dùng foreground URLSession hoặc              │
│      background URLSession (không discretionary)             │
│                                                              │
│ ❌ Register task sau didFinishLaunching                       │
│    → Crash hoặc handler không được gọi                       │
│                                                              │
│ ❌ Dùng hack (silent audio, fake location) thay BGTask       │
│    → App Store reject, tốn pin, user complaints              │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ Best Practices ────────────────────────────────────────────┐
│                                                              │
│ ✅ Thiết kế task idempotent — có thể chạy lại an toàn       │
│    (task bị kill giữa chừng → lần sau chạy lại từ đầu OK)   │
│                                                              │
│ ✅ Checkpoint cho processing tasks dài                       │
│    → Lưu progress, resume từ checkpoint nếu bị cancel       │
│                                                              │
│ ✅ Kết hợp nhiều cơ chế:                                     │
│    • BGAppRefreshTask: periodic refresh                      │
│    • Silent Push: server-triggered urgent refresh            │
│    • Background URLSession: large transfers                  │
│    • BGProcessingTask: heavy maintenance                     │
│                                                              │
│ ✅ Tôn trọng system resources                                │
│    • requiresExternalPower = true cho task nặng              │
│    • requiresNetworkConnectivity cho sync tasks              │
│    • Checkpoint + cancel gracefully                          │
│                                                              │
│ ✅ Đo lường trong production                                 │
│    • Log task duration, success rate                         │
│    • Monitor bao lâu iOS mới schedule task                   │
│    • Alert nếu task không chạy quá X ngày                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

Điểm mấu chốt cho Senior: background execution trên iOS là **cooperative** — app yêu cầu, iOS quyết định. Thiết kế app để **không phụ thuộc** vào exact timing của background task. Data phải nhất quán dù task bị cancel giữa chừng, chạy trễ vài giờ, hoặc không chạy. BGTaskScheduler cho phép gợi ý cho iOS biết app cần gì (network, power, timing), và iOS sẽ tìm thời điểm tối ưu nhất cho cả user lẫn system.
