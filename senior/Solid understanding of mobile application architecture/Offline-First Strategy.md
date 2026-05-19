# Offline-First Strategy — Giải thích chi tiết cho Senior iOS Developer

## 1. Offline-First là gì?

### Tư duy truyền thống (Online-First):

```
User mở app → Gọi API → Chờ response → Hiển thị dữ liệu
                           │
                           └── Mất mạng? → Hiện lỗi / Màn hình trắng
```

App **phụ thuộc hoàn toàn** vào network. Không có mạng = không hoạt động được.

### Tư duy Offline-First:

```
User mở app → Đọc từ local database → Hiển thị NGAY LẬP TỨC
                  │
                  └── Đồng thời gọi API (nếu có mạng)
                          │
                          └── Có dữ liệu mới? → Cập nhật local DB → UI tự refresh
                          └── Mất mạng? → Không sao, user đã thấy dữ liệu rồi
```

**Nguyên tắc cốt lõi:** Local database là **source of truth** cho UI. Network chỉ là cơ chế **đồng bộ** dữ liệu giữa local và server.

### Tại sao quan trọng?

**Trải nghiệm người dùng tốt hơn nhiều:** App mở lên là có dữ liệu ngay, không phải chờ spinner xoay. Ngay cả khi có mạng, đọc từ local database nhanh hơn gọi API hàng chục lần (vài millisecond vs vài trăm millisecond đến vài giây).

**Thực tế sử dụng:** User di chuyển trong thang máy, tàu điện ngầm, vùng sóng yếu... Mạng không ổn định là **bình thường**, không phải ngoại lệ. App tốt phải xử lý điều này mượt mà.

**Tiết kiệm tài nguyên:** Giảm số lượng API call, tiết kiệm pin và data cho user.

---

## 2. Kiến trúc tổng thể của Offline-First

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│          (SwiftUI View / UIKit ViewController)          │
│                         │                               │
│                         │ observe                       │
│                         ▼                               │
│               ┌──────────────────┐                      │
│               │    Repository    │  ← Single entry point│
│               └────────┬─────────┘                      │
│                        │                                │
│              ┌─────────┴──────────┐                     │
│              ▼                    ▼                      │
│   ┌────────────────┐   ┌─────────────────┐              │
│   │  Local Store   │   │  Remote Source   │              │
│   │  (Core Data /  │   │  (API Client)   │              │
│   │   SwiftData)   │   │                 │              │
│   └────────────────┘   └─────────────────┘              │
│              ▲                    │                      │
│              │     sync          │                      │
│              └───────────────────┘                      │
│                                                         │
│   ┌─────────────────────────────────────────┐           │
│   │          Sync Engine                     │           │
│   │  • Queue offline changes                 │           │
│   │  • Retry when network available          │           │
│   │  • Conflict resolution                   │           │
│   └─────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

**Luồng đọc dữ liệu (Read):**

```
UI → Repository → Local Store → Trả dữ liệu NGAY
                → Remote Source → Có dữ liệu mới? → Cập nhật Local Store → UI tự refresh
```

**Luồng ghi dữ liệu (Write):**

```
UI → Repository → Ghi vào Local Store NGAY (UI cập nhật tức thì)
               → Có mạng? → Gửi lên server
               → Không có mạng? → Đưa vào Sync Queue → Gửi khi có mạng lại
```

---

## 3. Triển khai Local Store với SwiftData

### 3.1. Định nghĩa Model

```swift
import SwiftData

// ──────── Server response model ────────
struct ArticleDTO: Codable {
    let id: String
    let title: String
    let content: String
    let authorName: String
    let updatedAt: Date
    let version: Int
}

// ──────── Local persistent model ────────
@Model
final class ArticleEntity {
    #Unique<ArticleEntity>([\.serverId])
    
    @Attribute(.unique)
    var serverId: String
    
    var title: String
    var content: String
    var authorName: String
    
    // ──── Sync metadata ────
    var serverUpdatedAt: Date      // Thời điểm server cập nhật lần cuối
    var localUpdatedAt: Date       // Thời điểm local cập nhật lần cuối
    var version: Int               // Server version, dùng cho conflict detection
    var syncStatus: SyncStatus     // Trạng thái đồng bộ
    var lastSyncedAt: Date?        // Lần sync thành công cuối
    
    init(from dto: ArticleDTO) {
        self.serverId = dto.id
        self.title = dto.title
        self.content = dto.content
        self.authorName = dto.authorName
        self.serverUpdatedAt = dto.updatedAt
        self.localUpdatedAt = dto.updatedAt
        self.version = dto.version
        self.syncStatus = .synced
        self.lastSyncedAt = Date()
    }
    
    func update(from dto: ArticleDTO) {
        self.title = dto.title
        self.content = dto.content
        self.authorName = dto.authorName
        self.serverUpdatedAt = dto.updatedAt
        self.version = dto.version
        self.syncStatus = .synced
        self.lastSyncedAt = Date()
    }
}

// ──────── Trạng thái đồng bộ ────────
enum SyncStatus: Int, Codable {
    case synced           // Đã đồng bộ với server
    case pendingUpload    // Có thay đổi local chưa gửi lên server
    case pendingDelete    // Đã xóa local, chưa xóa trên server
    case conflict         // Có xung đột giữa local và server
}
```

**Tại sao cần `syncStatus`?** Đây là trường quan trọng nhất trong offline-first. Nó cho biết mỗi record đang ở trạng thái nào trong vòng đời đồng bộ, giúp Sync Engine biết cần làm gì với từng record.

### 3.2. Local Store

```swift
actor LocalArticleStore {
    private let modelContainer: ModelContainer
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // ──────── READ: UI đọc dữ liệu ────────
    
    func fetchArticles() throws -> [ArticleEntity] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.syncStatus != .pendingDelete },
            sortBy: [SortDescriptor(\.serverUpdatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    func fetchArticle(serverId: String) throws -> ArticleEntity? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try context.fetch(descriptor).first
    }
    
    // ──────── WRITE: Lưu dữ liệu từ server ────────
    
    func upsertFromServer(_ dtos: [ArticleDTO]) throws {
        let context = ModelContext(modelContainer)
        
        for dto in dtos {
            let descriptor = FetchDescriptor<ArticleEntity>(
                predicate: #Predicate { $0.serverId == dto.id }
            )
            
            if let existing = try context.fetch(descriptor).first {
                // Nếu local có thay đổi chưa sync → conflict
                if existing.syncStatus == .pendingUpload {
                    existing.syncStatus = .conflict
                    // Lưu server version riêng để user quyết định sau
                } else {
                    existing.update(from: dto)
                }
            } else {
                let entity = ArticleEntity(from: dto)
                context.insert(entity)
            }
        }
        
        try context.save()
    }
    
    // ──────── WRITE: User tạo/sửa offline ────────
    
    func saveLocalChange(serverId: String, title: String, content: String) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        
        guard let entity = try context.fetch(descriptor).first else { return }
        
        entity.title = title
        entity.content = content
        entity.localUpdatedAt = Date()
        entity.syncStatus = .pendingUpload   // Đánh dấu cần sync
        
        try context.save()
    }
    
    func markAsDeleted(serverId: String) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        
        guard let entity = try context.fetch(descriptor).first else { return }
        
        entity.syncStatus = .pendingDelete   // Không xóa thật, đánh dấu
        try context.save()
    }
    
    // ──────── SYNC: Lấy các record cần sync ────────
    
    func fetchPendingUploads() throws -> [ArticleEntity] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.syncStatus == .pendingUpload }
        )
        return try context.fetch(descriptor)
    }
    
    func fetchPendingDeletes() throws -> [ArticleEntity] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<ArticleEntity>(
            predicate: #Predicate { $0.syncStatus == .pendingDelete }
        )
        return try context.fetch(descriptor)
    }
}
```

---

## 4. Repository Pattern — Single Entry Point

Repository là lớp trung gian duy nhất mà ViewModel giao tiếp. ViewModel **không biết** dữ liệu đến từ local hay remote:

```swift
protocol ArticleRepositoryProtocol {
    func getArticles() -> AsyncStream<[Article]>
    func getArticle(id: String) async throws -> Article
    func saveArticle(_ article: Article) async throws
    func deleteArticle(id: String) async throws
}

final class ArticleRepository: ArticleRepositoryProtocol {
    private let localStore: LocalArticleStore
    private let remoteSource: ArticleAPIClient
    private let syncEngine: SyncEngine
    private let networkMonitor: NetworkMonitor
    
    init(
        localStore: LocalArticleStore,
        remoteSource: ArticleAPIClient,
        syncEngine: SyncEngine,
        networkMonitor: NetworkMonitor
    ) {
        self.localStore = localStore
        self.remoteSource = remoteSource
        self.syncEngine = syncEngine
        self.networkMonitor = networkMonitor
    }
    
    // ──────── READ: Trả dữ liệu local NGAY + refresh từ server ────────
    
    func getArticles() -> AsyncStream<[Article]> {
        AsyncStream { continuation in
            Task {
                // Bước 1: Trả dữ liệu local NGAY LẬP TỨC
                if let localArticles = try? await localStore.fetchArticles() {
                    let articles = localArticles.map { Article(from: $0) }
                    continuation.yield(articles)
                }
                
                // Bước 2: Fetch từ server (nếu có mạng)
                if networkMonitor.isConnected {
                    do {
                        let dtos = try await remoteSource.fetchArticles()
                        try await localStore.upsertFromServer(dtos)
                        
                        // Bước 3: Đọc lại từ local (đã merge) và emit bản mới
                        if let updatedArticles = try? await localStore.fetchArticles() {
                            let articles = updatedArticles.map { Article(from: $0) }
                            continuation.yield(articles)
                        }
                    } catch {
                        // Network error → không sao, user đã có dữ liệu local
                        print("Remote fetch failed: \(error). Using cached data.")
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    // ──────── WRITE: Ghi local NGAY + queue sync ────────
    
    func saveArticle(_ article: Article) async throws {
        // Bước 1: Lưu vào local DB ngay (UI cập nhật tức thì)
        try await localStore.saveLocalChange(
            serverId: article.id,
            title: article.title,
            content: article.content
        )
        
        // Bước 2: Queue sync lên server
        if networkMonitor.isConnected {
            try await syncEngine.syncPendingChanges()
        }
        // Nếu không có mạng → record đã được đánh dấu pendingUpload
        // SyncEngine sẽ tự sync khi có mạng lại
    }
    
    // ──────── DELETE: Soft delete local + queue sync ────────
    
    func deleteArticle(id: String) async throws {
        // Soft delete — đánh dấu pendingDelete, không xóa thật
        try await localStore.markAsDeleted(serverId: id)
        
        if networkMonitor.isConnected {
            try await syncEngine.syncPendingDeletes()
        }
    }
}
```

**UI nhận 2 lần emit:**
1. Lần 1: Dữ liệu local (cũ nhưng NGAY LẬP TỨC)
2. Lần 2: Dữ liệu đã merge với server (mới nhất)

User thấy app **phản hồi tức thì**, sau đó dữ liệu tự cập nhật nếu có thay đổi.

---

## 5. Network Monitor — Theo dõi trạng thái mạng

```swift
import Network

@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected = true
    private(set) var connectionType: ConnectionType = .unknown
    
    // Callback khi mạng khôi phục — trigger sync
    var onConnectionRestored: (() -> Void)?
    
    enum ConnectionType {
        case wifi, cellular, ethernet, unknown
    }
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            let wasDisconnected = !self.isConnected
            
            Task { @MainActor in
                self.isConnected = path.status == .satisfied
                self.connectionType = self.getConnectionType(path)
                
                // Mạng vừa khôi phục → trigger sync
                if wasDisconnected && self.isConnected {
                    self.onConnectionRestored?()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        return .unknown
    }
    
    deinit {
        monitor.cancel()
    }
}
```

---

## 6. Sync Engine — Xử lý đồng bộ và hàng đợi

### 6.1. Pending Change Queue

```swift
// Mỗi thay đổi offline được lưu thành 1 record trong queue
@Model
final class PendingChangeEntity {
    @Attribute(.unique) var changeId: String
    
    var entityType: String          // "Article", "Comment"...
    var entityId: String            // Server ID của entity
    var changeType: ChangeType      // create, update, delete
    var payload: Data?              // JSON data cần gửi lên server
    var createdAt: Date             // Thời điểm tạo change
    var retryCount: Int             // Số lần đã thử gửi
    var maxRetries: Int             // Giới hạn retry
    var lastError: String?          // Lỗi gần nhất
}

enum ChangeType: Int, Codable {
    case create
    case update
    case delete
}
```

### 6.2. Sync Engine

```swift
actor SyncEngine {
    private let localStore: LocalArticleStore
    private let remoteSource: ArticleAPIClient
    private let changeQueue: PendingChangeQueue
    
    private var isSyncing = false
    
    // ──────── Main sync loop ────────
    
    func syncAll() async {
        guard !isSyncing else { return }  // Tránh sync chồng chéo
        isSyncing = true
        defer { isSyncing = false }
        
        // 1. Push local changes lên server
        await pushPendingChanges()
        
        // 2. Pull server changes về local
        await pullRemoteChanges()
    }
    
    // ──────── PUSH: Gửi thay đổi local lên server ────────
    
    private func pushPendingChanges() async {
        do {
            let pendingChanges = try await changeQueue.fetchPending()
            
            for change in pendingChanges {
                do {
                    switch change.changeType {
                    case .create:
                        try await pushCreate(change)
                    case .update:
                        try await pushUpdate(change)
                    case .delete:
                        try await pushDelete(change)
                    }
                    
                    // Thành công → xóa khỏi queue
                    try await changeQueue.remove(change)
                    
                } catch let error as APIError where error.isConflict {
                    // Server trả về 409 Conflict → cần resolve
                    try await handleConflict(change: change, error: error)
                    
                } catch {
                    // Lỗi khác (network timeout, server 500...)
                    try await changeQueue.incrementRetry(change, error: error)
                    
                    if change.retryCount >= change.maxRetries {
                        try await changeQueue.markAsFailed(change)
                        // Thông báo user: "Không thể đồng bộ thay đổi X"
                    }
                }
            }
        } catch {
            print("Push sync failed: \(error)")
        }
    }
    
    // ──────── PULL: Lấy dữ liệu mới từ server ────────
    
    private func pullRemoteChanges() async {
        do {
            // Chỉ lấy thay đổi từ lần sync cuối (incremental sync)
            let lastSyncTimestamp = await getLastSyncTimestamp()
            let changes = try await remoteSource.fetchChanges(since: lastSyncTimestamp)
            
            // Upsert vào local store
            try await localStore.upsertFromServer(changes.updated)
            
            // Xóa các record đã bị xóa trên server
            for deletedId in changes.deletedIds {
                try await localStore.hardDelete(serverId: deletedId)
            }
            
            await updateLastSyncTimestamp(Date())
        } catch {
            print("Pull sync failed: \(error)")
        }
    }
    
    // ──────── Retry với Exponential Backoff ────────
    
    private func retryDelay(for retryCount: Int) -> Duration {
        // 1s, 2s, 4s, 8s, 16s... (max 60s)
        let seconds = min(pow(2.0, Double(retryCount)), 60.0)
        return .seconds(seconds)
    }
}
```

---

## 7. Conflict Resolution — Xử lý xung đột

Đây là phần **phức tạp nhất** của offline-first. Conflict xảy ra khi:

```
Timeline:
──────────────────────────────────────────────
t1: User A (offline) sửa title = "Hello"
t2: User B (online) sửa title = "World" → server cập nhật
t3: User A có mạng lại → push title = "Hello" → CONFLICT!
    Server đã có version mới từ User B
──────────────────────────────────────────────
```

### 7.1. Các chiến lược Conflict Resolution

**Chiến lược 1: Last Write Wins (LWW)** — Đơn giản nhất

```swift
// Ai ghi sau cùng thì thắng, dựa trên timestamp
func resolveLastWriteWins(local: ArticleEntity, remote: ArticleDTO) -> ArticleEntity {
    if local.localUpdatedAt > remote.updatedAt {
        // Local mới hơn → giữ local, push lên server
        return local
    } else {
        // Remote mới hơn → cập nhật local từ remote
        local.update(from: remote)
        return local
    }
}
```

Ưu điểm: Đơn giản, không cần user can thiệp. Nhược điểm: **Mất dữ liệu** — thay đổi của một bên bị ghi đè hoàn toàn.

**Chiến lược 2: Server Wins** — An toàn nhất

```swift
// Server luôn đúng. Local change bị ghi đè
func resolveServerWins(local: ArticleEntity, remote: ArticleDTO) {
    local.update(from: remote)
    local.syncStatus = .synced
    // Thông báo user: "Bài viết đã được cập nhật bởi người khác"
}
```

Phù hợp khi dữ liệu server là "official" (ví dụ: giá sản phẩm, thông tin chính thức).

**Chiến lược 3: Client Wins** — User không mất công sức

```swift
// Local change luôn được ưu tiên
func resolveClientWins(local: ArticleEntity, remote: ArticleDTO) async throws {
    // Force push local version lên server
    try await remoteSource.forceUpdate(
        id: local.serverId,
        title: local.title,
        content: local.content,
        baseVersion: remote.version  // Gửi kèm version để server biết
    )
    local.version = remote.version + 1
    local.syncStatus = .synced
}
```

**Chiến lược 4: Field-Level Merge** — Thông minh nhất

```swift
// Merge từng field riêng lẻ
func resolveFieldLevelMerge(
    base: ArticleSnapshot,     // Phiên bản gốc trước khi cả 2 sửa
    local: ArticleEntity,      // Phiên bản local
    remote: ArticleDTO         // Phiên bản server
) -> MergeResult {
    
    var merged = MergeResult()
    var hasConflict = false
    
    // Title: ai sửa thì lấy của người đó
    let localChangedTitle = local.title != base.title
    let remoteChangedTitle = remote.title != base.title
    
    switch (localChangedTitle, remoteChangedTitle) {
    case (true, false):
        merged.title = local.title           // Chỉ local sửa → lấy local
    case (false, true):
        merged.title = remote.title          // Chỉ remote sửa → lấy remote
    case (false, false):
        merged.title = base.title            // Không ai sửa → giữ nguyên
    case (true, true):
        if local.title == remote.title {
            merged.title = local.title       // Cả 2 sửa giống nhau → OK
        } else {
            hasConflict = true               // Cả 2 sửa KHÁC nhau → conflict
            merged.titleConflict = ConflictDetail(
                localValue: local.title,
                remoteValue: remote.title,
                baseValue: base.title
            )
        }
    }
    
    // Tương tự cho content, authorName...
    // ...
    
    merged.requiresUserIntervention = hasConflict
    return merged
}
```

**Chiến lược 5: User Decides** — Cho user quyết định khi có conflict

```swift
// Khi phát hiện conflict → hiển thị UI cho user chọn
struct ConflictResolutionView: View {
    let conflict: ArticleConflict
    let onResolve: (ResolutionChoice) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Phát hiện xung đột")
                .font(.headline)
            
            Text("Bài viết này đã được chỉnh sửa ở nơi khác trong khi bạn đang offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Phiên bản của bạn (local)
            GroupBox("Phiên bản của bạn") {
                VStack(alignment: .leading) {
                    Text("Tiêu đề: \(conflict.localVersion.title)")
                    Text("Sửa lúc: \(conflict.localVersion.updatedAt.formatted())")
                    Text(conflict.localVersion.content)
                        .lineLimit(3)
                }
            }
            
            // Phiên bản trên server
            GroupBox("Phiên bản trên server") {
                VStack(alignment: .leading) {
                    Text("Tiêu đề: \(conflict.remoteVersion.title)")
                    Text("Sửa lúc: \(conflict.remoteVersion.updatedAt.formatted())")
                    Text(conflict.remoteVersion.content)
                        .lineLimit(3)
                }
            }
            
            // Lựa chọn
            HStack(spacing: 12) {
                Button("Giữ bản của tôi") {
                    onResolve(.keepLocal)
                }
                
                Button("Dùng bản server") {
                    onResolve(.keepRemote)
                }
                
                Button("Giữ cả hai") {
                    onResolve(.keepBoth)      // Tạo 2 bản copy
                }
            }
        }
        .padding()
    }
}
```

### 7.2. Version Vector / Optimistic Locking

Cách phổ biến nhất để **phát hiện** conflict ở server:

```swift
// Client gửi kèm version hiện tại
struct UpdateArticleRequest: Codable {
    let id: String
    let title: String
    let content: String
    let expectedVersion: Int    // "Tôi đang sửa trên version 5"
}

// Server kiểm tra
// Pseudocode phía server:
func handleUpdate(request: UpdateArticleRequest) {
    let currentArticle = database.find(request.id)
    
    if currentArticle.version != request.expectedVersion {
        // Version không khớp → ai đó đã sửa trước
        throw HTTPError.conflict(
            currentVersion: currentArticle.version,
            yourVersion: request.expectedVersion,
            serverData: currentArticle
        )
    }
    
    // Version khớp → cập nhật bình thường
    currentArticle.update(from: request)
    currentArticle.version += 1
    database.save(currentArticle)
}
```

```swift
// Client xử lý 409 Conflict
func pushUpdate(_ change: PendingChangeEntity) async throws {
    do {
        try await remoteSource.updateArticle(
            id: change.entityId,
            payload: change.payload,
            expectedVersion: change.version
        )
    } catch let error as APIError where error.statusCode == 409 {
        // Server trả về version mới nhất
        let serverVersion = error.serverData
        let localVersion = try await localStore.fetchArticle(serverId: change.entityId)
        
        // Áp dụng chiến lược conflict resolution
        let resolved = conflictResolver.resolve(
            local: localVersion,
            remote: serverVersion,
            strategy: .fieldLevelMerge
        )
        
        if resolved.requiresUserIntervention {
            await notifyUserOfConflict(resolved)
        } else {
            try await localStore.applyMergeResult(resolved)
            // Retry push với version mới
            try await pushUpdate(change)
        }
    }
}
```

---

## 8. Background Sync với BGTaskScheduler

Sync không chỉ xảy ra khi user mở app. iOS cho phép chạy background task để sync:

```swift
import BackgroundTasks

class BackgroundSyncManager {
    
    static let syncTaskIdentifier = "com.myapp.background.sync"
    
    // ──────── Đăng ký task khi app launch ────────
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.syncTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    // ──────── Schedule task khi app vào background ────────
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Self.syncTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // Sau 15 phút
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background sync: \(error)")
        }
    }
    
    // ──────── Xử lý khi iOS cho phép chạy ────────
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule task tiếp theo
        scheduleBackgroundSync()
        
        let syncTask = Task {
            do {
                try await syncEngine.syncAll()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        
        // Nếu iOS yêu cầu dừng (hết thời gian)
        task.expirationHandler = {
            syncTask.cancel()
        }
    }
}
```

---

## 9. Optimistic UI — Tạo cảm giác tức thì

Khi user thực hiện action (like, comment, edit...), **cập nhật UI ngay lập tức** trước khi server confirm:

```swift
class ArticleViewModel: ObservableObject {
    @Published var article: Article
    @Published var syncIndicator: SyncIndicator = .synced
    
    func updateTitle(_ newTitle: String) async {
        let oldTitle = article.title
        
        // 1. Cập nhật UI NGAY (optimistic)
        article.title = newTitle
        syncIndicator = .saving          // Hiện icon "đang lưu..."
        
        do {
            // 2. Lưu local + queue sync
            try await repository.saveArticle(article)
            syncIndicator = .synced      // ✅ Hiện icon "đã lưu"
        } catch {
            // 3. Nếu lỗi → rollback UI
            article.title = oldTitle
            syncIndicator = .error       // ❌ Hiện icon "lỗi"
        }
    }
}

// UI indicator nhỏ gọn
enum SyncIndicator {
    case synced          // ✓ 
    case saving          // ↻ đang lưu
    case pendingSync     // ☁ chờ mạng để đồng bộ
    case error           // ✕ lỗi
}
```

```swift
// View hiển thị sync status tinh tế
struct ArticleEditorView: View {
    @ObservedObject var viewModel: ArticleViewModel
    
    var body: some View {
        VStack {
            TextField("Tiêu đề", text: $viewModel.article.title)
                .onChange(of: viewModel.article.title) { _, newValue in
                    Task { await viewModel.updateTitle(newValue) }
                }
            
            // Sync indicator nhỏ ở góc
            HStack {
                Spacer()
                SyncStatusBadge(status: viewModel.syncIndicator)
            }
        }
    }
}

struct SyncStatusBadge: View {
    let status: SyncIndicator
    
    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Đã lưu")
            case .saving:
                ProgressView()
                    .scaleEffect(0.7)
                Text("Đang lưu...")
            case .pendingSync:
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.orange)
                Text("Chờ kết nối mạng")
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Lỗi đồng bộ")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
```

---

## 10. Incremental Sync vs Full Sync

### Full Sync — Tải toàn bộ

```swift
// Mỗi lần sync đều tải TẤT CẢ dữ liệu
func fullSync() async throws {
    let allArticles = try await remoteSource.fetchAllArticles()
    try await localStore.replaceAll(with: allArticles)
}
// Vấn đề: tốn bandwidth, chậm khi dữ liệu lớn
```

### Incremental Sync — Chỉ tải phần thay đổi (phổ biến hơn)

```swift
// Chỉ tải dữ liệu thay đổi từ lần sync cuối
func incrementalSync() async throws {
    let lastSync = getLastSyncTimestamp()  // Ví dụ: "2026-03-20T10:00:00Z"
    
    // Server trả về CHỈ những record thay đổi sau thời điểm đó
    let changes = try await remoteSource.fetchChanges(since: lastSync)
    
    // changes.updated: [ArticleDTO] — các record mới/sửa
    // changes.deletedIds: [String] — các record đã xóa
    // changes.syncToken: String — token cho lần sync tiếp theo
    
    try await localStore.upsertFromServer(changes.updated)
    try await localStore.hardDeleteByIds(changes.deletedIds)
    
    saveLastSyncTimestamp(Date())
    saveSyncToken(changes.syncToken)
}
```

### Cursor-based Sync — Cho dữ liệu rất lớn

```swift
// Sync theo trang, không tải hết một lúc
func cursorBasedSync() async throws {
    var cursor: String? = getLastSyncCursor()
    
    repeat {
        let page = try await remoteSource.fetchChanges(cursor: cursor, limit: 100)
        try await localStore.upsertFromServer(page.items)
        
        cursor = page.nextCursor
        saveLastSyncCursor(cursor)        // Lưu cursor để resume nếu bị interrupt
    } while cursor != nil
}
```

---

## 11. Chọn chiến lược phù hợp theo use case

| Use case | Conflict Strategy | Sync Strategy | Ví dụ |
|---|---|---|---|
| Read-heavy, ít edit | Server Wins | Incremental pull | App tin tức, e-commerce catalog |
| Collaborative editing | Field-Level Merge + User Decides | Real-time (WebSocket) + incremental | Google Docs, Notion |
| Personal data, 1 user | Last Write Wins | Incremental push/pull | App ghi chú cá nhân, todo list |
| Financial / critical | Server Wins + Audit Log | Full sync + verify | Banking, inventory |
| Social actions | Client Wins (optimistic) | Event queue | Like, follow, bookmark |

---

## 12. Tổng kết

Offline-first không chỉ là "cache data rồi hiển thị khi mất mạng". Đối với Senior iOS Developer, nó là một **chiến lược thiết kế toàn diện** bao gồm: local database làm source of truth cho UI, sync engine với queue và retry để đồng bộ đáng tin cậy, conflict resolution phù hợp với bản chất dữ liệu, và optimistic UI để tạo trải nghiệm mượt mà. Mục tiêu cuối cùng là user **không bao giờ cảm thấy** app "không hoạt động" — dù đang ở bất kỳ điều kiện mạng nào.

Bạn muốn mình đi sâu hơn vào phần nào? Ví dụ: CRDT cho collaborative editing, CloudKit sync, hay cách test offline scenarios?
