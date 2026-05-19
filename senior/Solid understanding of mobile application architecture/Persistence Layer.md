# Persistence Layer — Giải thích chi tiết cho Senior iOS Developer

## 1. Tổng quan: Tại sao Senior cần hiểu rõ Persistence?

Mọi app đều cần lưu trữ dữ liệu. Sai lầm phổ biến là **dùng sai công cụ cho sai mục đích** — ví dụ lưu token vào UserDefaults (không an toàn), lưu ảnh vào Core Data (phình database), hay dùng Core Data cho dữ liệu chỉ cần key-value đơn giản (overkill).

Senior iOS Developer cần biết **đặc tính của từng công cụ** để chọn đúng:

```
┌────────────────────────────────────────────────────────────────┐
│                    iOS Persistence Landscape                    │
│                                                                │
│  Đơn giản ◄──────────────────────────────────► Phức tạp       │
│                                                                │
│  UserDefaults    Keychain    File System    Core Data    SQLite │
│  (key-value)    (secure)    (binary)       (ORM)       (raw)  │
│                                                                │
│  Settings       Tokens      Images         Entities     Custom │
│  Flags          Passwords   Videos         Relations    Query  │
│  Small data     Secrets     Documents      Graph        Perf   │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. UserDefaults — Key-Value đơn giản

### 2.1. Bản chất

UserDefaults là một **plist file** (Property List) được iOS quản lý. Khi app launch, **toàn bộ file** được load vào memory. Khi bạn đọc giá trị, bạn đọc từ memory (rất nhanh). Khi bạn ghi, iOS ghi vào memory trước rồi **async flush xuống disk** sau.

```
~/Library/Preferences/com.myapp.bundle.plist

<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>hasCompletedOnboarding</key>
    <true/>
    <key>selectedTheme</key>
    <string>dark</string>
    <key>lastOpenedTab</key>
    <integer>2</integer>
</dict>
</plist>
```

### 2.2. Khi nào dùng

```swift
// ✅ PHÙ HỢP: Settings, preferences, flags, trạng thái nhỏ
UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
UserDefaults.standard.set("dark", forKey: "selectedTheme")
UserDefaults.standard.set(2, forKey: "lastOpenedTab")
UserDefaults.standard.set(Date(), forKey: "lastSyncDate")

// ❌ KHÔNG PHÙ HỢP:
// - Dữ liệu nhạy cảm (token, password) → dùng Keychain
// - Dữ liệu lớn (array hàng nghìn items) → dùng Core Data
// - Dữ liệu cần query phức tạp → dùng Core Data / SQLite
// - File binary (ảnh, video) → dùng File System
```

### 2.3. Wrapper an toàn với @propertyWrapper

```swift
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let container: UserDefaults
    
    init(_ key: String, defaultValue: T, container: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.container = container
    }
    
    var wrappedValue: T {
        get { container.object(forKey: key) as? T ?? defaultValue }
        set { container.set(newValue, forKey: key) }
    }
}

// Dùng Codable cho kiểu phức tạp hơn
@propertyWrapper
struct CodableUserDefault<T: Codable> {
    let key: String
    let defaultValue: T
    let container: UserDefaults
    
    init(_ key: String, defaultValue: T, container: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.container = container
    }
    
    var wrappedValue: T {
        get {
            guard let data = container.data(forKey: key),
                  let value = try? JSONDecoder().decode(T.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                container.set(data, forKey: key)
            }
        }
    }
}
```

```swift
// ──────── Tập trung tất cả settings vào 1 nơi ────────

final class AppSettings {
    static let shared = AppSettings()
    
    @UserDefault("hasCompletedOnboarding", defaultValue: false)
    var hasCompletedOnboarding: Bool
    
    @UserDefault("selectedTheme", defaultValue: "system")
    var selectedTheme: String
    
    @UserDefault("lastOpenedTab", defaultValue: 0)
    var lastOpenedTab: Int
    
    @UserDefault("notificationsEnabled", defaultValue: true)
    var notificationsEnabled: Bool
    
    @CodableUserDefault("lastSyncDate", defaultValue: nil)
    var lastSyncDate: Date?
    
    @CodableUserDefault("recentSearches", defaultValue: [])
    var recentSearches: [String]
    
    @CodableUserDefault("userPreferences", defaultValue: UserPreferences.default)
    var userPreferences: UserPreferences
}

// Sử dụng
AppSettings.shared.hasCompletedOnboarding = true
let theme = AppSettings.shared.selectedTheme
```

### 2.4. App Groups — Chia sẻ giữa App và Extension

```swift
// Main App và Widget Extension cùng dùng chung UserDefaults
let sharedDefaults = UserDefaults(suiteName: "group.com.myapp.shared")

// Main App ghi:
sharedDefaults?.set(42, forKey: "unreadCount")

// Widget Extension đọc:
let count = sharedDefaults?.integer(forKey: "unreadCount") ?? 0
```

### 2.5. Lưu ý quan trọng

**Toàn bộ plist load vào memory khi app launch.** Nếu bạn lưu quá nhiều dữ liệu (ví dụ: array 10,000 items), nó sẽ làm chậm app launch và tốn memory. Quy tắc: UserDefaults chỉ cho dữ liệu **vài KB đến vài chục KB**.

**Không có encryption.** Dữ liệu lưu dưới dạng plist plain text. Trên device jailbroken, ai cũng đọc được. **Tuyệt đối không** lưu token, password, hay thông tin nhạy cảm ở đây.

**Không thread-safe cho write.** `UserDefaults.standard` read thì thread-safe, nhưng write từ nhiều thread có thể gây race condition. Nên ghi từ main thread hoặc dùng serial queue.

---

## 3. Keychain — Lưu trữ bảo mật

### 3.1. Bản chất

Keychain là **encrypted database** do iOS quản lý ở system level. Dữ liệu được mã hóa bằng hardware key (Secure Enclave trên device có Touch ID/Face ID). Ngay cả khi device bị jailbreak, dữ liệu Keychain vẫn được bảo vệ (tùy mức access control).

```
So sánh bảo mật:

UserDefaults:  ~/Library/Preferences/com.myapp.plist  → Plain text, ai cũng đọc được
File System:   ~/Documents/token.txt                   → Plain text trên disk
Keychain:      System Keychain (encrypted database)    → Encrypted by hardware
```

### 3.2. Keychain API gốc (rất phức tạp)

```swift
// ❌ API gốc của Apple — cực kỳ verbose và khó dùng
func saveToKeychain(key: String, data: Data) -> OSStatus {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    SecItemDelete(query as CFDictionary)  // Xóa cũ nếu có
    return SecItemAdd(query as CFDictionary, nil)
}

func readFromKeychain(key: String) -> Data? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess else { return nil }
    return result as? Data
}
```

### 3.3. Keychain Wrapper (cách Senior nên làm)

```swift
enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case unexpectedStatus(OSStatus)
    case encodingFailed
    case decodingFailed
}

final class KeychainManager {
    
    private let service: String
    private let accessGroup: String?
    
    init(service: String = Bundle.main.bundleIdentifier ?? "com.myapp",
         accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    // ──────── SAVE ────────
    
    func save(_ data: Data, for key: String, accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly) throws {
        var query = baseQuery(for: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessibility
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            // Đã tồn tại → update
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility
            ]
            let updateStatus = SecItemUpdate(
                baseQuery(for: key) as CFDictionary,
                updateAttributes as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // Convenience: save String
    func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data, for: key)
    }
    
    // Convenience: save Codable
    func save<T: Encodable>(_ object: T, for key: String) throws {
        let data = try JSONEncoder().encode(object)
        try save(data, for: key)
    }
    
    // ──────── READ ────────
    
    func readData(for key: String) throws -> Data {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.itemNotFound
        }
        
        return data
    }
    
    func readString(for key: String) throws -> String {
        let data = try readData(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return string
    }
    
    func read<T: Decodable>(_ type: T.Type, for key: String) throws -> T {
        let data = try readData(for: key)
        return try JSONDecoder().decode(type, from: data)
    }
    
    // ──────── DELETE ────────
    
    func delete(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // ──────── Base query ────────
    
    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
```

### 3.4. Token Store — Use case phổ biến nhất

```swift
protocol TokenStoreProtocol {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    var isAccessTokenExpired: Bool { get }
    func saveTokens(access: String, refresh: String, expiresIn: TimeInterval)
    func clearAll()
}

final class KeychainTokenStore: TokenStoreProtocol {
    
    private let keychain: KeychainManager
    
    private enum Keys {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let tokenExpiry = "auth.tokenExpiry"
    }
    
    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
    }
    
    var accessToken: String? {
        try? keychain.readString(for: Keys.accessToken)
    }
    
    var refreshToken: String? {
        try? keychain.readString(for: Keys.refreshToken)
    }
    
    var isAccessTokenExpired: Bool {
        guard let expiryDate = try? keychain.read(Date.self, for: Keys.tokenExpiry) else {
            return true
        }
        // Coi token hết hạn sớm 60s để tránh race condition
        return Date() >= expiryDate.addingTimeInterval(-60)
    }
    
    func saveTokens(access: String, refresh: String, expiresIn: TimeInterval) {
        try? keychain.save(access, for: Keys.accessToken)
        try? keychain.save(refresh, for: Keys.refreshToken)
        
        let expiryDate = Date().addingTimeInterval(expiresIn)
        try? keychain.save(expiryDate, for: Keys.tokenExpiry)
    }
    
    func clearAll() {
        try? keychain.delete(for: Keys.accessToken)
        try? keychain.delete(for: Keys.refreshToken)
        try? keychain.delete(for: Keys.tokenExpiry)
    }
}
```

### 3.5. Keychain Accessibility Levels

```swift
// Mức độ bảo mật khi nào Keychain item có thể được đọc:

kSecAttrAccessibleWhenUnlockedThisDeviceOnly
// ✅ KHUYÊN DÙNG cho hầu hết trường hợp
// Chỉ đọc được khi device đang unlock
// Không backup sang device khác
// → Token, session data

kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
// Đọc được sau khi user unlock lần đầu sau reboot
// → Push notification tokens (cần đọc khi app ở background)

kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
// CHỈ tồn tại khi device có passcode
// Nếu user xóa passcode → data bị xóa
// → Dữ liệu cực kỳ nhạy cảm

kSecAttrAccessibleAlwaysThisDeviceOnly
// Luôn đọc được (ngay cả khi device locked)
// → Hiếm khi cần, bảo mật thấp nhất
```

### 3.6. Keychain tồn tại sau khi xóa app

**Đặc biệt quan trọng:** Keychain data **KHÔNG bị xóa** khi user xóa app và cài lại. Đây là hành vi mặc định của iOS. Điều này có thể gây bug:

```swift
// User xóa app → cài lại → Keychain vẫn có token cũ
// App tưởng user đã login → crash hoặc hiển thị sai

// ✅ Giải pháp: Check first launch và clear keychain
final class AppLaunchManager {
    
    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"
    
    static func handleFirstLaunchIfNeeded(tokenStore: TokenStoreProtocol) {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        
        if isFirstLaunch {
            // Xóa Keychain data cũ từ lần cài trước
            tokenStore.clearAll()
            UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        }
    }
}
```

---

## 4. Core Data / SwiftData — Structured Data Store

### 4.1. Khi nào dùng

Khi dữ liệu có **cấu trúc phức tạp**, **quan hệ giữa các entity**, cần **query/filter/sort**, và **số lượng lớn** (hàng nghìn đến hàng triệu records).

```
Ví dụ phù hợp:
- Danh sách sản phẩm (filter theo category, sort theo giá)
- Tin nhắn chat (query theo conversation, sort theo thời gian)
- Offline cache cho API response
- Todo list với tags, projects, subtasks
- Danh bạ với groups, favorites

Không phù hợp:
- Lưu 3-4 cái settings → UserDefaults
- Lưu access token → Keychain
- Lưu ảnh/video → File System (chỉ lưu file path trong Core Data)
```

### 4.2. SwiftData — Modern API (iOS 17+)

```swift
import SwiftData

// ──────── Model Definition ────────

@Model
final class Conversation {
    @Attribute(.unique) var id: String
    var title: String
    var createdAt: Date
    var isPinned: Bool
    
    // Quan hệ 1-nhiều: 1 Conversation có nhiều Messages
    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message] = []
    
    // Quan hệ nhiều-nhiều
    @Relationship
    var participants: [Contact] = []
    
    // Computed property — không lưu vào DB
    var lastMessage: Message? {
        messages.sorted(by: { $0.sentAt > $1.sentAt }).first
    }
    
    var unreadCount: Int {
        messages.filter { !$0.isRead }.count
    }
    
    init(id: String, title: String) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.isPinned = false
    }
}

@Model
final class Message {
    @Attribute(.unique) var id: String
    var content: String
    var sentAt: Date
    var isRead: Bool
    var type: MessageType
    
    // Không lưu binary data trong DB → lưu path
    var attachmentPath: String?
    
    var conversation: Conversation?
    var sender: Contact?
    
    init(id: String, content: String, type: MessageType = .text) {
        self.id = id
        self.content = content
        self.sentAt = Date()
        self.isRead = false
        self.type = type
    }
}

enum MessageType: Int, Codable {
    case text
    case image
    case video
    case file
}

@Model
final class Contact {
    @Attribute(.unique) var id: String
    var name: String
    var avatarPath: String?       // Lưu path, không lưu ảnh trực tiếp
    var phoneNumber: String?
    
    @Relationship(inverse: \Conversation.participants)
    var conversations: [Conversation] = []
    
    init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
```

### 4.3. Query & Filter

```swift
// ──────── Trong SwiftUI ────────

struct ConversationListView: View {
    
    // Tự động fetch và observe changes
    @Query(
        filter: #Predicate<Conversation> { !$0.messages.isEmpty },
        sort: [
            SortDescriptor(\Conversation.isPinned, order: .reverse),  // Pinned lên đầu
            SortDescriptor(\Conversation.createdAt, order: .reverse)  // Mới nhất trước
        ]
    )
    private var conversations: [Conversation]
    
    var body: some View {
        List(conversations) { conversation in
            ConversationRow(conversation: conversation)
        }
    }
}

// ──────── Trong Repository / ViewModel (non-SwiftUI) ────────

actor MessageStore {
    private let modelContainer: ModelContainer
    
    func searchMessages(keyword: String, in conversationId: String) throws -> [Message] {
        let context = ModelContext(modelContainer)
        
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> {
                $0.conversation?.id == conversationId &&
                $0.content.localizedStandardContains(keyword)
            },
            sortBy: [SortDescriptor(\.sentAt, order: .reverse)]
        )
        
        return try context.fetch(descriptor)
    }
    
    func fetchUnreadCount(for conversationId: String) throws -> Int {
        let context = ModelContext(modelContainer)
        
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> {
                $0.conversation?.id == conversationId &&
                !$0.isRead
            }
        )
        
        return try context.fetchCount(descriptor)
    }
    
    // Batch update — hiệu quả hơn fetch rồi update từng cái
    func markAllAsRead(in conversationId: String) throws {
        let context = ModelContext(modelContainer)
        
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate<Message> {
                $0.conversation?.id == conversationId &&
                !$0.isRead
            }
        )
        
        let unreadMessages = try context.fetch(descriptor)
        for message in unreadMessages {
            message.isRead = true
        }
        
        try context.save()
    }
}
```

### 4.4. Core Data — Mature API (iOS 10+, phổ biến hơn trong production)

```swift
// ──────── Core Data Stack ────────

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    let persistentContainer: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "MyAppModel")
        
        // Tự động merge changes từ background context
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed: \(error)")
            }
        }
    }
    
    // Background context cho heavy operations (import, batch update...)
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // Perform background task
    func performBackground<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await persistentContainer.performBackgroundTask { context in
            let result = try block(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        }
    }
}
```

```swift
// ──────── Batch Import — hiệu suất cao ────────

extension CoreDataStack {
    
    /// Import hàng nghìn records mà không block main thread
    func batchImportProducts(_ dtos: [ProductDTO]) async throws {
        try await performBackground { context in
            // NSBatchInsertRequest — insert trực tiếp vào SQLite, bypass managed object
            let request = NSBatchInsertRequest(
                entityName: "ProductEntity",
                objects: dtos.map { dto in
                    [
                        "serverId": dto.id,
                        "name": dto.name,
                        "price": dto.price,
                        "updatedAt": dto.updatedAt
                    ] as [String: Any]
                }
            )
            request.resultType = .count
            
            let result = try context.execute(request) as? NSBatchInsertResult
            let count = result?.result as? Int ?? 0
            print("Imported \(count) products")
        }
    }
}
```

### 4.5. Core Data vs SwiftData — Khi nào chọn cái nào

| Tiêu chí | SwiftData | Core Data |
|---|---|---|
| Minimum iOS | iOS 17+ | iOS 10+ |
| Syntax | Swift macro, modern | NSManagedObject, verbose |
| SwiftUI integration | Tuyệt vời (@Query) | Tốt (@FetchRequest) |
| Migration | Tự động (đơn giản) | Manual (linh hoạt hơn) |
| Background processing | Đơn giản hơn | NSBatchInsertRequest, performBackgroundTask |
| Maturity | Còn mới, có bug | Rất mature, battle-tested |
| CloudKit sync | Hỗ trợ | Hỗ trợ rất tốt |
| Complex queries | Hạn chế hơn | NSFetchRequest rất mạnh |

**Khuyến nghị:** App mới, iOS 17+ → SwiftData. App cần hỗ trợ iOS cũ hơn hoặc cần advanced features → Core Data. Cả hai đều dùng SQLite bên dưới.

---

## 5. File System — Binary Data & Large Files

### 5.1. iOS Sandbox Directories

```
App Sandbox/
├── Documents/              ← User-generated content, iTunes backup
│   ├── reports/
│   └── exports/
│
├── Library/
│   ├── Caches/             ← Redownloadable data, iOS có thể xóa khi thiếu storage
│   │   ├── images/
│   │   └── api_cache/
│   │
│   ├── Application Support/ ← App data quan trọng, iTunes backup
│   │   └── database.sqlite
│   │
│   └── Preferences/        ← UserDefaults plist (iOS quản lý)
│
└── tmp/                    ← Temporary files, iOS xóa bất cứ lúc nào
    └── upload_temp/
```

### 5.2. File Manager Wrapper

```swift
final class FileStorageManager {
    
    enum Directory {
        case documents          // User content, backed up
        case caches             // Redownloadable, can be purged
        case applicationSupport // App data, backed up
        case temporary          // Short-lived
        
        var url: URL {
            switch self {
            case .documents:
                return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            case .caches:
                return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            case .applicationSupport:
                return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            case .temporary:
                return FileManager.default.temporaryDirectory
            }
        }
    }
    
    private let fileManager = FileManager.default
    
    // ──────── SAVE ────────
    
    func save(_ data: Data, filename: String, in directory: Directory, subfolder: String? = nil) throws -> URL {
        var targetURL = directory.url
        
        if let subfolder {
            targetURL = targetURL.appendingPathComponent(subfolder)
        }
        
        // Tạo folder nếu chưa có
        if !fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
        }
        
        let fileURL = targetURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    // ──────── READ ────────
    
    func read(filename: String, from directory: Directory, subfolder: String? = nil) throws -> Data {
        var fileURL = directory.url
        if let subfolder {
            fileURL = fileURL.appendingPathComponent(subfolder)
        }
        fileURL = fileURL.appendingPathComponent(filename)
        
        return try Data(contentsOf: fileURL)
    }
    
    // ──────── DELETE ────────
    
    func delete(filename: String, from directory: Directory, subfolder: String? = nil) throws {
        var fileURL = directory.url
        if let subfolder {
            fileURL = fileURL.appendingPathComponent(subfolder)
        }
        fileURL = fileURL.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    // ──────── CACHE SIZE ────────
    
    func cacheSize(subfolder: String? = nil) throws -> Int64 {
        var url = Directory.caches.url
        if let subfolder {
            url = url.appendingPathComponent(subfolder)
        }
        return try directorySize(at: url)
    }
    
    func clearCache(subfolder: String? = nil) throws {
        var url = Directory.caches.url
        if let subfolder {
            url = url.appendingPathComponent(subfolder)
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    private func directorySize(at url: URL) throws -> Int64 {
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )
        return try contents.reduce(0) { total, fileURL in
            let size = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return total + Int64(size)
        }
    }
}
```

### 5.3. Image Cache — Use case phổ biến nhất

```swift
actor ImageCacheManager {
    private let fileStorage: FileStorageManager
    private let memoryCache = NSCache<NSString, UIImage>()
    private let subfolder = "image_cache"
    
    init(fileStorage: FileStorageManager = FileStorageManager()) {
        self.fileStorage = fileStorage
        
        // Giới hạn memory cache
        memoryCache.countLimit = 100              // Tối đa 100 ảnh
        memoryCache.totalCostLimit = 50 * 1024 * 1024  // Tối đa 50MB
    }
    
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)
        
        // 1. Check memory cache (nhanh nhất)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        
        // 2. Check disk cache
        if let data = try? fileStorage.read(
            filename: key,
            from: .caches,
            subfolder: subfolder
        ), let image = UIImage(data: data) {
            // Đưa vào memory cache cho lần sau
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }
        
        // 3. Download
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }
        
        // Lưu vào cả 2 tầng cache
        memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
        _ = try? fileStorage.save(data, filename: key, in: .caches, subfolder: subfolder)
        
        return image
    }
    
    func clearAll() throws {
        memoryCache.removeAllObjects()
        try fileStorage.clearCache(subfolder: subfolder)
    }
    
    private func cacheKey(for url: URL) -> String {
        // Hash URL thành filename an toàn
        url.absoluteString.data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .prefix(128) + ".cache"  // Giới hạn độ dài filename
    }
}
```

### 5.4. Quy tắc chọn Directory

```
Documents/
├── ✅ File user tạo (export PDF, saved document)
├── ✅ Dữ liệu KHÔNG thể tải lại từ server
├── ⚠️ Được backup → đừng để file quá lớn
└── ⚠️ User thấy trong Files app (nếu enable)

Library/Caches/
├── ✅ Ảnh đã download, API response cache
├── ✅ Dữ liệu CÓ THỂ tải lại từ server
├── ⚠️ iOS TỰ ĐỘNG XÓA khi thiếu storage
└── ⚠️ KHÔNG được backup

Library/Application Support/
├── ✅ Database files (SQLite, Core Data)
├── ✅ App configuration không phải user content
├── ✅ Được backup
└── ⚠️ User KHÔNG thấy trong Files app

tmp/
├── ✅ File tạm khi upload/download
├── ✅ File tạm khi xử lý ảnh/video
├── ⚠️ iOS xóa BẤT CỨ LÚC NÀO (kể cả khi app đang chạy)
└── ⚠️ KHÔNG được backup
```

---

## 6. SQLite trực tiếp (GRDB) — Kiểm soát tối đa

### 6.1. Khi nào cần SQLite trực tiếp thay vì Core Data?

**Hiệu năng query phức tạp** — Core Data thêm overhead cho object graph management. Khi cần query thuần SQL (JOIN, GROUP BY, window functions...) với dataset lớn, SQLite trực tiếp nhanh hơn đáng kể.

**Full-text search** — SQLite có FTS5 (Full-Text Search) tích hợp sẵn, rất mạnh. Core Data không expose tính năng này.

**Kiểm soát migration** — Core Data migration có thể unpredictable với schema phức tạp. SQLite cho bạn viết migration SQL chính xác.

**Lightweight** — Không cần object graph, change tracking, faulting... Chỉ cần đọc/ghi data đơn giản nhưng hiệu quả.

### 6.2. GRDB — Thư viện SQLite phổ biến nhất cho Swift

```swift
import GRDB

// ──────── Model: conform Record ────────

struct Product: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: String
    var name: String
    var price: Decimal
    var categoryId: String
    var stock: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Tên table
    static var databaseTableName: String { "products" }
}

struct Category: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: String
    var name: String
    var parentId: String?
    var sortOrder: Int
    
    static var databaseTableName: String { "categories" }
}

// ──────── JOIN result ────────
struct ProductWithCategory: Decodable, FetchableRecord {
    var product: Product
    var category: Category
}
```

```swift
// ──────── Database Setup & Migration ────────

final class DatabaseManager {
    let dbQueue: DatabaseQueue
    
    init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrator.migrate(dbQueue)
    }
    
    // Convenience cho in-memory testing
    static func inMemory() throws -> DatabaseManager {
        try DatabaseManager(path: ":memory:")
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // Migration v1: Tạo tables
        migrator.registerMigration("v1_createTables") { db in
            try db.create(table: "categories") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("parentId", .text)
                    .references("categories", onDelete: .setNull)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
            }
            
            try db.create(table: "products") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("price", .text).notNull()   // Decimal as text
                t.column("categoryId", .text).notNull()
                    .references("categories", onDelete: .restrict)
                t.column("stock", .integer).notNull().defaults(to: 0)
                t.column("isActive", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            
            // Indexes cho query thường dùng
            try db.create(
                index: "idx_products_categoryId",
                on: "products",
                columns: ["categoryId"]
            )
            try db.create(
                index: "idx_products_isActive_updatedAt",
                on: "products",
                columns: ["isActive", "updatedAt"]
            )
        }
        
        // Migration v2: Thêm Full-Text Search
        migrator.registerMigration("v2_addFTS") { db in
            try db.create(virtualTable: "products_fts", using: FTS5()) { t in
                t.synchronize(withTable: "products")   // Tự đồng bộ với products table
                t.tokenizer = .unicode61()              // Hỗ trợ tiếng Việt
                t.column("name")
            }
        }
        
        // Migration v3: Thêm column mới
        migrator.registerMigration("v3_addProductDescription") { db in
            try db.alter(table: "products") { t in
                t.add(column: "description", .text).defaults(to: "")
            }
        }
        
        return migrator
    }
}
```

### 6.3. Query — Sức mạnh của SQL thuần

```swift
extension DatabaseManager {
    
    // ──────── Basic CRUD ────────
    
    func saveProduct(_ product: Product) throws {
        try dbQueue.write { db in
            try product.save(db)   // INSERT or UPDATE
        }
    }
    
    func deleteProduct(id: String) throws {
        try dbQueue.write { db in
            _ = try Product.deleteOne(db, id: id)
        }
    }
    
    // ──────── Query Builder (type-safe) ────────
    
    func fetchActiveProducts(in categoryId: String, sortedBy: ProductSortOption) throws -> [Product] {
        try dbQueue.read { db in
            var request = Product
                .filter(Column("isActive") == true)
                .filter(Column("categoryId") == categoryId)
            
            switch sortedBy {
            case .priceAsc:    request = request.order(Column("price").asc)
            case .priceDesc:   request = request.order(Column("price").desc)
            case .newest:      request = request.order(Column("createdAt").desc)
            case .name:        request = request.order(Column("name").collating(.localizedCaseInsensitiveCompare))
            }
            
            return try request.fetchAll(db)
        }
    }
    
    // ──────── JOIN — Core Data không hỗ trợ trực tiếp ────────
    
    func fetchProductsWithCategory() throws -> [ProductWithCategory] {
        try dbQueue.read { db in
            let request = Product
                .including(required: Product.belongsTo(Category.self))
                .filter(Column("isActive") == true)
                .order(Column("updatedAt").desc)
            
            return try ProductWithCategory.fetchAll(db, request)
        }
    }
    
    // ──────── Raw SQL cho query phức tạp ────────
    
    func fetchCategorySummary() throws -> [CategorySummary] {
        try dbQueue.read { db in
            let sql = """
                SELECT 
                    c.id,
                    c.name,
                    COUNT(p.id) as productCount,
                    COALESCE(SUM(p.stock), 0) as totalStock,
                    COALESCE(AVG(CAST(p.price AS REAL)), 0) as avgPrice
                FROM categories c
                LEFT JOIN products p ON p.categoryId = c.id AND p.isActive = 1
                GROUP BY c.id
                ORDER BY productCount DESC
                """
            
            return try CategorySummary.fetchAll(db, sql: sql)
        }
    }
    
    // ──────── Full-Text Search ────────
    
    func searchProducts(query: String) throws -> [Product] {
        try dbQueue.read { db in
            let pattern = FTS5Pattern(matchingAnyTokenIn: query)
            
            return try Product
                .joining(required: Product.matching(pattern))
                .fetchAll(db)
        }
    }
    
    // ──────── Pagination hiệu quả ────────
    
    func fetchProducts(page: Int, pageSize: Int = 20) throws -> [Product] {
        try dbQueue.read { db in
            try Product
                .filter(Column("isActive") == true)
                .order(Column("updatedAt").desc)
                .limit(pageSize, offset: page * pageSize)
                .fetchAll(db)
        }
    }
    
    // ──────── Observe changes (Reactive) ────────
    
    func observeProducts(in categoryId: String) -> some Publisher<[Product], Error> {
        let observation = ValueObservation.tracking { db in
            try Product
                .filter(Column("categoryId") == categoryId)
                .filter(Column("isActive") == true)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
        }
        
        return observation.publisher(in: dbQueue)
    }
}
```

### 6.4. Batch Operations — Hiệu năng cao

```swift
extension DatabaseManager {
    
    /// Import 10,000 products trong 1 transaction
    func batchImport(_ products: [Product]) throws {
        try dbQueue.write { db in
            // 1 transaction cho tất cả → nhanh hơn N lần so với N transactions
            for product in products {
                try product.save(db)
            }
        }
        // 10,000 records: ~0.5-1 giây (vs ~30 giây nếu mỗi record 1 transaction)
    }
    
    /// Batch delete với điều kiện
    func deleteInactiveProducts(olderThan date: Date) throws -> Int {
        try dbQueue.write { db in
            try Product
                .filter(Column("isActive") == false)
                .filter(Column("updatedAt") < date)
                .deleteAll(db)
        }
    }
}
```

---

## 7. So sánh tổng hợp — Decision Matrix

```
╔═══════════════════╦═════════════╦═══════════╦════════════════╦════════════╦═══════════╗
║   Tiêu chí        ║ UserDefaults║ Keychain  ║ Core Data/     ║ File System║ SQLite    ║
║                   ║             ║           ║ SwiftData      ║            ║ (GRDB)    ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Dữ liệu phù hợp  ║ Settings,   ║ Token,    ║ Entities có    ║ Ảnh, video,║ Data cần  ║
║                   ║ flags, nhỏ  ║ password, ║ quan hệ, query ║ PDF, file  ║ SQL phức  ║
║                   ║             ║ secrets   ║ phức tạp       ║ lớn        ║ tạp, FTS  ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Kích thước data   ║ < 100KB     ║ < 10KB    ║ MB → GB        ║ Unlimited  ║ MB → GB   ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Encryption        ║ ❌ Không    ║ ✅ Hardware║ ❌ (có thể bật)║ ❌ Không   ║ SQLCipher ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Query/Filter/Sort ║ ❌          ║ ❌ Cơ bản ║ ✅ Tốt         ║ ❌         ║ ✅ Rất tốt║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Relationships     ║ ❌          ║ ❌        ║ ✅ Object graph ║ ❌         ║ ✅ SQL JOIN║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Thread safety     ║ ⚠️ Read OK  ║ ✅        ║ ⚠️ Cần context ║ ⚠️ Manual  ║ ✅ GRDB   ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Tồn tại sau xóa  ║ ❌ Xóa cùng║ ✅ Tồn tại║ ❌ Xóa cùng app║ ❌ Xóa cùng║ ❌ Xóa    ║
║ app               ║ app        ║           ║                ║ app        ║ cùng app  ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ iCloud backup     ║ ✅          ║ Tùy config║ Tùy directory  ║ Tùy dir    ║ Tùy dir   ║
╠═══════════════════╬═════════════╬═══════════╬════════════════╬════════════╬═══════════╣
║ Learning curve    ║ Rất thấp    ║ Trung bình║ Cao            ║ Thấp       ║ Trung bình║
╚═══════════════════╩═════════════╩═══════════╩════════════════╩════════════╩═══════════╝
```

---

## 8. Persistence Abstraction Layer — Gom tất cả lại

Senior thường tạo một **abstraction layer** để phần còn lại của app không cần biết dữ liệu lưu ở đâu:

```swift
// ──────── Protocol cho ViewModel/UseCase ────────
protocol ProductStorageProtocol {
    func fetchAll() async throws -> [Product]
    func fetch(id: String) async throws -> Product?
    func save(_ product: Product) async throws
    func delete(id: String) async throws
    func search(query: String) async throws -> [Product]
}

// ──────── Implementation chọn đúng tool cho đúng việc ────────
final class ProductStorage: ProductStorageProtocol {
    private let database: DatabaseManager      // GRDB cho structured data
    private let fileStorage: FileStorageManager // File system cho images
    private let settings: AppSettings          // UserDefaults cho preferences
    
    func save(_ product: Product) async throws {
        // 1. Lưu product data vào SQLite
        try database.saveProduct(product)
        
        // 2. Nếu có ảnh → lưu file riêng, chỉ giữ path trong DB
        if let imageData = product.imageData {
            let filename = "\(product.id).jpg"
            let url = try fileStorage.save(
                imageData,
                filename: filename,
                in: .caches,
                subfolder: "product_images"
            )
            try database.updateProductImagePath(id: product.id, path: url.path)
        }
        
        // 3. Cập nhật last modified date vào UserDefaults
        settings.lastProductUpdateDate = Date()
    }
}
```

---

## 9. Tổng kết

Persistence Layer với Senior iOS Developer không chỉ là "biết dùng Core Data". Nó là khả năng **phân tích đặc tính dữ liệu** (kích thước, độ nhạy cảm, cấu trúc, tần suất truy cập, yêu cầu query) để chọn đúng công cụ, kết hợp nhiều công cụ khi cần, và đóng gói tất cả sau một abstraction layer sạch sẽ để phần còn lại của app không phụ thuộc vào implementation cụ thể. UserDefaults cho settings nhỏ, Keychain cho secrets, Core Data/SwiftData cho dữ liệu có quan hệ, File System cho binary lớn, và SQLite trực tiếp khi cần kiểm soát tối đa hiệu năng — mỗi công cụ có vị trí riêng và Senior biết chính xác khi nào dùng cái nào.

Bạn muốn mình đi sâu hơn phần nào? Ví dụ: Core Data migration strategies, GRDB + Combine observation, hay encryption cho SQLite (SQLCipher)?
