```Swift
// ============================================================
// .userActivity TRONG SWIFTUI — GIẢI THÍCH CHI TIẾT
// ============================================================
// .userActivity() và .onContinueUserActivity() là SwiftUI wrappers
// cho NSUserActivity — hệ thống của Apple phục vụ:
//
// 1. HANDOFF: tiếp tục hoạt động từ iPhone → Mac → iPad
// 2. SPOTLIGHT: index nội dung vào iOS Search
// 3. SIRI SHORTCUTS: gợi ý hành động cho Siri
// 4. UNIVERSAL LINKS: mở deep link trong app
// 5. STATE RESTORATION: khôi phục trạng thái khi relaunch
//
// NSUserActivity mô tả "user ĐANG LÀM GÌ" tại 1 thời điểm:
// - Đang xem bài viết X
// - Đang edit document Y
// - Đang browse category Z
// → Các devices khác / Spotlight / Siri có thể "tiếp tục" hoạt động đó.
// ============================================================

import SwiftUI
import CoreSpotlight


// ╔══════════════════════════════════════════════════════════╗
// ║  1. NSUSER ACTIVITY CƠ BẢN — KHÁI NIỆM NỀN TẢNG        ║
// ╚══════════════════════════════════════════════════════════╝

// NSUserActivity có 3 thành phần chính:
//
// 1. activityType: String identifier (reverse-domain)
//    "com.myapp.viewArticle", "com.myapp.editDocument"
//    → PHẢI khai báo trong Info.plist > NSUserActivityTypes
//
// 2. userInfo: [String: Any] dictionary
//    Dữ liệu kèm theo: article ID, page number, search query
//
// 3. Properties:
//    - title: hiển thị trong Handoff banner, Spotlight
//    - isEligibleForHandoff: cho phép chuyển sang device khác
//    - isEligibleForSearch: index vào Spotlight search
//    - isEligibleForPrediction: gợi ý trong Siri Suggestions
//    - webpageURL: fallback URL nếu device không có app
//    - contentAttributeSet: metadata cho Spotlight (thumbnail, desc)

// INFO.PLIST SETUP (BẮT BUỘC):
// <key>NSUserActivityTypes</key>
// <array>
//     <string>com.myapp.viewArticle</string>
//     <string>com.myapp.editDocument</string>
//     <string>com.myapp.viewProfile</string>
//     <string>com.myapp.search</string>
// </array>


// ╔══════════════════════════════════════════════════════════╗
// ║  2. .userActivity() — ADVERTISE ACTIVITY                 ║
// ╚══════════════════════════════════════════════════════════╝

// .userActivity() khai báo: "User ĐANG LÀM GÌ trên view này"
// SwiftUI TỰ ĐỘNG:
// - Tạo NSUserActivity khi view APPEAR
// - Gọi update closure để populate data
// - Set becomeCurrent() → advertise cho Handoff/Spotlight
// - Invalidate khi view DISAPPEAR

// === 2a. Cú pháp cơ bản ===

struct ArticleDetailView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .font(.title.bold())
                Text(article.content)
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle(article.title)
        
        // === Advertise activity ===
        .userActivity(ActivityTypes.viewArticle) { activity in
            // Closure được gọi khi view appear + khi dependencies thay đổi
            
            // Title hiển thị trên Handoff banner
            activity.title = article.title
            
            // Data kèm theo để restore trên device khác
            activity.userInfo = [
                "articleID": article.id,
                "articleTitle": article.title
            ]
            
            // Handoff: cho phép tiếp tục trên Mac/iPad
            activity.isEligibleForHandoff = true
            
            // Spotlight: index vào iOS Search
            activity.isEligibleForSearch = true
            
            // Siri: gợi ý "Mở bài viết X" trong Suggestions
            activity.isEligibleForPrediction = true
            
            // Fallback URL cho device không có app
            activity.webpageURL = URL(string: "https://myapp.com/articles/\(article.id)")
            
            // Spotlight metadata
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = article.title
            attributes.contentDescription = String(article.content.prefix(200))
            attributes.thumbnailData = nil // UIImage data nếu có
            activity.contentAttributeSet = attributes
            
            // Keywords cho Spotlight search
            activity.keywords = Set(article.tags)
        }
    }
}

// Activity type constants
enum ActivityTypes {
    static let viewArticle = "com.myapp.viewArticle"
    static let editDocument = "com.myapp.editDocument"
    static let viewProfile = "com.myapp.viewProfile"
    static let search = "com.myapp.search"
}

// Data models
struct Article: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let tags: [String]
    let authorID: String
}


// === 2b. Activity cập nhật khi data thay đổi ===

struct LiveEditorView: View {
    @State private var title = "My Document"
    @State private var content = ""
    @State private var cursorPosition = 0
    
    var body: some View {
        VStack {
            TextField("Title", text: $title)
                .font(.title2.bold())
            
            TextEditor(text: $content)
        }
        .padding()
        
        // Update closure được gọi LẠI khi view re-render
        // → Activity luôn chứa data MỚI NHẤT
        .userActivity(ActivityTypes.editDocument) { activity in
            activity.title = "Editing: \(title)"
            activity.isEligibleForHandoff = true
            activity.userInfo = [
                "docTitle": title,
                "docContent": content,
                "cursorPosition": cursorPosition
            ]
            // Khi user chuyển sang Mac → Mac nhận đúng nội dung
            // đang edit + vị trí cursor
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  3. .onContinueUserActivity() — NHẬN ACTIVITY            ║
// ╚══════════════════════════════════════════════════════════╝

// .onContinueUserActivity() xử lý khi app NHẬN activity từ:
// - Handoff từ device khác
// - Tap Spotlight search result
// - Tap Siri Suggestion
// - Universal Link

// === 3a. Nhận activity ở root view ===

struct ContentView: View {
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab = 0
    @State private var restoredSearchQuery = ""
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $navigationPath) {
                ArticleListView()
                    .navigationDestination(for: Article.self) { article in
                        ArticleDetailView(article: article)
                    }
                    .navigationDestination(for: String.self) { profileID in
                        Text("Profile: \(profileID)")
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)
            
            SearchView(initialQuery: restoredSearchQuery)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)
        }
        
        // === Nhận "View Article" activity ===
        .onContinueUserActivity(ActivityTypes.viewArticle) { activity in
            handleViewArticle(activity)
        }
        
        // === Nhận "Edit Document" activity ===
        .onContinueUserActivity(ActivityTypes.editDocument) { activity in
            handleEditDocument(activity)
        }
        
        // === Nhận "Search" activity ===
        .onContinueUserActivity(ActivityTypes.search) { activity in
            handleSearch(activity)
        }
        
        // === Nhận "View Profile" ===
        .onContinueUserActivity(ActivityTypes.viewProfile) { activity in
            handleViewProfile(activity)
        }
    }
    
    private func handleViewArticle(_ activity: NSUserActivity) {
        guard let articleID = activity.userInfo?["articleID"] as? String,
              let articleTitle = activity.userInfo?["articleTitle"] as? String
        else { return }
        
        selectedTab = 0
        
        // Navigate đến article
        let article = Article(
            id: articleID,
            title: articleTitle,
            content: "", // Fetch full content from API
            tags: [],
            authorID: ""
        )
        navigationPath.append(article)
    }
    
    private func handleEditDocument(_ activity: NSUserActivity) {
        guard let title = activity.userInfo?["docTitle"] as? String
        else { return }
        
        // Restore editor state
        print("Continuing edit: \(title)")
    }
    
    private func handleSearch(_ activity: NSUserActivity) {
        guard let query = activity.userInfo?["searchQuery"] as? String
        else { return }
        
        selectedTab = 1
        restoredSearchQuery = query
    }
    
    private func handleViewProfile(_ activity: NSUserActivity) {
        guard let profileID = activity.userInfo?["profileID"] as? String
        else { return }
        
        selectedTab = 0
        navigationPath.append(profileID)
    }
}

// Placeholder views
struct ArticleListView: View {
    var body: some View {
        List { Text("Articles...") }
            .navigationTitle("Articles")
    }
}

struct SearchView: View {
    var initialQuery: String
    var body: some View {
        Text("Search: \(initialQuery)")
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  4. HANDOFF — TIẾP TỤC TRÊN DEVICE KHÁC                 ║
// ╚══════════════════════════════════════════════════════════╝

// Handoff cho phép chuyển hoạt động giữa iPhone ↔ iPad ↔ Mac
// cùng Apple ID, cùng WiFi/Bluetooth.
//
// Flow:
// 1. iPhone: user đọc Article X → .userActivity() advertise
// 2. Mac: hiện icon Handoff trên Dock → user click
// 3. Mac app nhận NSUserActivity qua .onContinueUserActivity()
// 4. Mac app navigate đến Article X
//
// Yêu cầu:
// - Cùng Apple ID trên cả 2 devices
// - Handoff enabled trong Settings
// - Bluetooth ON trên cả 2 devices
// - Cùng WiFi network (hoặc bluetooth range)
// - App installed trên cả 2 devices (hoặc có webpageURL fallback)
// - activityType khai báo trong Info.plist

struct HandoffArticleView: View {
    let article: Article
    @State private var scrollProgress = 0.0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title).font(.title.bold())
                Text(article.content)
            }
            .padding()
        }
        .userActivity(ActivityTypes.viewArticle) { activity in
            // HANDOFF CONFIG
            activity.title = article.title
            activity.isEligibleForHandoff = true
            
            // Required: type phải trong Info.plist NSUserActivityTypes
            // activity.activityType đã set bởi parameter
            
            // UserInfo: data cần thiết để resume trên device khác
            activity.userInfo = [
                "articleID": article.id,
                "articleTitle": article.title,
                "scrollProgress": scrollProgress
            ]
            
            // Fallback: nếu device nhận KHÔNG có app
            // → Safari mở URL này
            activity.webpageURL = URL(string: "https://myapp.com/article/\(article.id)")
            
            // needsSave: SwiftUI tự handle, nhưng có thể set thủ công
            // cho streaming updates (document editing)
            activity.needsSave = true
        }
    }
}

// === Handoff với document streaming (realtime sync) ===

struct HandoffDocumentEditor: View {
    @State private var documentContent = ""
    @State private var lastSyncTime = Date.now
    
    var body: some View {
        TextEditor(text: $documentContent)
            .padding()
            .userActivity(ActivityTypes.editDocument) { activity in
                activity.title = "Editing Document"
                activity.isEligibleForHandoff = true
                activity.needsSave = true // Đánh dấu có data mới
                
                activity.userInfo = [
                    "content": documentContent,
                    "timestamp": lastSyncTime.timeIntervalSince1970
                ]
                
                // Delegate cho streaming updates
                // activity.delegate = coordinator
                // → userActivityWillSave(_:) được gọi trước khi send
            }
            .onChange(of: documentContent) { _, _ in
                lastSyncTime = .now
                // SwiftUI tự gọi lại update closure
            }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  5. SPOTLIGHT SEARCH — INDEX VÀO iOS SEARCH              ║
// ╚══════════════════════════════════════════════════════════╝

// isEligibleForSearch = true → nội dung xuất hiện trong iOS Search
// (Swipe down trên Home Screen → search)

struct SpotlightArticleView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title).font(.title.bold())
                Text("By: \(article.authorID)").foregroundStyle(.secondary)
                Text(article.content)
            }
            .padding()
        }
        .userActivity(ActivityTypes.viewArticle) { activity in
            // === SPOTLIGHT INDEXING ===
            activity.isEligibleForSearch = true
            activity.title = article.title
            
            // Rich metadata cho search results
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = article.title
            attributes.contentDescription = String(article.content.prefix(300))
            attributes.identifier = article.id
            attributes.relatedUniqueIdentifier = article.id
            attributes.domainIdentifier = "articles"
            
            // Keywords: user search "swift tutorial" → tìm thấy bài viết
            attributes.keywords = article.tags
            
            // Thumbnail (nếu có)
            // attributes.thumbnailData = imageData
            
            // Author info
            attributes.authorNames = [article.authorID]
            
            // Content dates
            attributes.contentCreationDate = .now
            attributes.contentModificationDate = .now
            
            activity.contentAttributeSet = attributes
            
            // Keywords trên activity level
            activity.keywords = Set(article.tags + [article.title])
            
            // Search uniqueness
            activity.persistentIdentifier = article.id
            // Tránh duplicate trong search results
        }
    }
}


// === Spotlight indexing hàng loạt (không cần view) ===

class SpotlightIndexer {
    
    static func indexArticles(_ articles: [Article]) {
        let items = articles.map { article -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = article.title
            attributes.contentDescription = String(article.content.prefix(300))
            attributes.keywords = article.tags
            // attributes.thumbnailData = ...
            
            return CSSearchableItem(
                uniqueIdentifier: article.id,
                domainIdentifier: "articles",
                attributeSet: attributes
            )
        }
        
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                print("Spotlight indexing failed: \(error)")
            } else {
                print("✅ Indexed \(items.count) articles")
            }
        }
    }
    
    // Xoá index khi item bị xoá
    static func deindexArticle(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [id]
        ) { error in
            if let error { print("Deindex failed: \(error)") }
        }
    }
    
    // Xoá tất cả
    static func deindexAll() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error { print("Deindex all failed: \(error)") }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  6. SIRI SHORTCUTS & PREDICTIONS                         ║
// ╚══════════════════════════════════════════════════════════╝

// isEligibleForPrediction = true → Siri học thói quen user
// và gợi ý hành động trên Lock Screen, Search, Siri Suggestions widget.

struct SiriShortcutDemo: View {
    let article: Article
    
    var body: some View {
        Text(article.title)
        .userActivity(ActivityTypes.viewArticle) { activity in
            // === SIRI SUGGESTIONS ===
            activity.isEligibleForPrediction = true
            activity.title = article.title
            
            // Siri suggestion subtitle
            activity.suggestedInvocationPhrase = "Đọc \(article.title)"
            // User có thể nói: "Hey Siri, đọc SwiftUI Tutorial"
            
            // Persistent ID giúp Siri track frequency
            activity.persistentIdentifier = article.id
            
            activity.userInfo = [
                "articleID": article.id,
                "articleTitle": article.title
            ]
            
            // Search attributes cũng hiện trong Suggestions
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = article.title
            attributes.contentDescription = "Tiếp tục đọc bài viết"
            activity.contentAttributeSet = attributes
        }
    }
}

// SIRI LEARNS:
// User mở "SwiftUI Tutorial" mỗi sáng 8h
// → Siri gợi ý trên Lock Screen lúc 7:55
// → "Đọc SwiftUI Tutorial" xuất hiện trong Siri Suggestions
//
// User thường search "flutter" sau lunch
// → Siri gợi ý "Search: flutter" lúc 12:30

// === Donate activity thủ công (không cần view) ===

func donateArticleActivity(article: Article) {
    let activity = NSUserActivity(activityType: ActivityTypes.viewArticle)
    activity.title = article.title
    activity.isEligibleForPrediction = true
    activity.isEligibleForSearch = true
    activity.suggestedInvocationPhrase = "Đọc \(article.title)"
    activity.persistentIdentifier = article.id
    activity.userInfo = ["articleID": article.id, "articleTitle": article.title]
    
    // Donate: báo cho Siri biết user đã thực hiện hành động này
    activity.becomeCurrent()
    // Sau đó invalidate khi không cần nữa:
    // activity.resignCurrent()
}


// ╔══════════════════════════════════════════════════════════╗
// ║  7. UNIVERSAL LINKS — DEEP LINKING                       ║
// ╚══════════════════════════════════════════════════════════╝

// Universal Links: tap link web → mở app thay vì Safari.
// NSUserActivity.activityType == NSUserActivityTypeBrowsingWeb

struct UniversalLinkHandler: View {
    @State private var path = NavigationPath()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $path) {
                Text("Home")
                    .navigationDestination(for: Article.self) { article in
                        ArticleDetailView(article: article)
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)
        }
        // === Handle Universal Links ===
        .onContinueUserActivity(
            NSUserActivityTypeBrowsingWeb   // Constant cho web URLs
        ) { activity in
            guard let url = activity.webpageURL else { return }
            handleUniversalLink(url)
        }
        // Hoặc dùng .onOpenURL cho URL schemes + Universal Links:
        .onOpenURL { url in
            handleUniversalLink(url)
        }
    }
    
    private func handleUniversalLink(_ url: URL) {
        // Parse URL: https://myapp.com/articles/article-123
        let components = url.pathComponents
        
        if components.contains("articles"),
           let articleID = components.last {
            selectedTab = 0
            let article = Article(
                id: articleID,
                title: "Loading...",
                content: "",
                tags: [],
                authorID: ""
            )
            path.append(article)
            // Fetch full article data from API...
        }
        
        if components.contains("profile"),
           let userID = components.last {
            // Navigate to profile
        }
    }
}

// UNIVERSAL LINKS SETUP:
// 1. Apple-app-site-association file trên server:
//    {
//      "applinks": {
//        "details": [{
//          "appID": "TEAMID.com.myapp",
//          "paths": ["/articles/*", "/profile/*"]
//        }]
//      }
//    }
// 2. Xcode: Capabilities > Associated Domains
//    → applinks:myapp.com
// 3. Info.plist hoặc Entitlements file


// ╔══════════════════════════════════════════════════════════╗
// ║  8. onOpenURL vs onContinueUserActivity                  ║
// ╚══════════════════════════════════════════════════════════╝

// ┌─────────────────────────┬──────────────────────────────────┐
// │ .onOpenURL              │ .onContinueUserActivity          │
// ├─────────────────────────┼──────────────────────────────────┤
// │ Nhận: URL               │ Nhận: NSUserActivity             │
// │ Sources:                │ Sources:                          │
// │ - Custom URL schemes    │ - Handoff                        │
// │   (myapp://path)        │ - Spotlight search result tap     │
// │ - Universal Links       │ - Siri Suggestion tap             │
// │ - Widgets               │ - Universal Links                │
// │ - App Clips             │ - .userActivity() từ device khác │
// │ - Other apps            │                                   │
// │                         │                                   │
// │ Data: URL chỉ chứa path│ Data: userInfo dict (rich data)   │
// │                         │ + CSSearchableItemAttributeSet    │
// │                         │                                   │
// │ API: đơn giản hơn       │ API: nhiều thông tin hơn          │
// └─────────────────────────┴──────────────────────────────────┘
//
// Production: thường dùng CẢ HAI
// - .onOpenURL: URL schemes, widget deep links
// - .onContinueUserActivity: Handoff, Spotlight, Siri

struct DeepLinkRouter: View {
    @State private var activeArticle: Article?
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Home").tag(0)
                .tabItem { Label("Home", systemImage: "house") }
        }
        
        // URL scheme: myapp://article/123
        .onOpenURL { url in
            if url.host() == "article",
               let id = url.pathComponents.dropFirst().first {
                navigateToArticle(id: String(id))
            }
        }
        
        // Handoff / Spotlight / Siri
        .onContinueUserActivity(ActivityTypes.viewArticle) { activity in
            if let id = activity.userInfo?["articleID"] as? String {
                navigateToArticle(id: id)
            }
        }
        
        // Spotlight result tap (CSSearchableItem)
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            // CSSearchableItemActionType: constant cho Spotlight tap
            if let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                navigateToArticle(id: id)
            }
        }
    }
    
    func navigateToArticle(id: String) {
        selectedTab = 0
        // Fetch and navigate...
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  9. APP LEVEL — SCENE DELEGATE INTEGRATION                ║
// ╚══════════════════════════════════════════════════════════╝

// Trong App struct, xử lý activities cho TOÀN APP.

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // View-level handlers
                .onContinueUserActivity(ActivityTypes.viewArticle) { activity in
                    // Handle tại root → navigate bất kỳ đâu
                }
                .onContinueUserActivity(ActivityTypes.search) { activity in
                    // Restore search
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    // Spotlight result tapped
                }
                .onOpenURL { url in
                    // URL schemes + Universal Links
                }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  10. PRODUCTION PATTERNS                                  ║
// ╚══════════════════════════════════════════════════════════╝

// === 10a. Centralized Deep Link Router ===

@Observable
final class DeepLinkManager {
    var selectedTab: AppTabType = .home
    var navigationPath = NavigationPath()
    var searchQuery = ""
    var pendingArticleID: String?
    
    enum AppTabType: Int {
        case home, search, profile
    }
    
    // Handle tất cả activity types
    func handle(_ activity: NSUserActivity) {
        switch activity.activityType {
        case ActivityTypes.viewArticle:
            handleViewArticle(activity)
            
        case ActivityTypes.search:
            handleSearch(activity)
            
        case ActivityTypes.viewProfile:
            handleViewProfile(activity)
            
        case CSSearchableItemActionType:
            handleSpotlightTap(activity)
            
        case NSUserActivityTypeBrowsingWeb:
            if let url = activity.webpageURL {
                handleUniversalLink(url)
            }
            
        default:
            print("Unknown activity: \(activity.activityType)")
        }
    }
    
    // Handle URL schemes
    func handle(url: URL) {
        guard let host = url.host() else { return }
        let pathParts = url.pathComponents.filter { $0 != "/" }
        
        switch host {
        case "article":
            if let id = pathParts.first {
                pendingArticleID = id
                selectedTab = .home
            }
        case "search":
            searchQuery = url.queryParameters?["q"] ?? ""
            selectedTab = .search
        case "profile":
            if let id = pathParts.first {
                selectedTab = .profile
            }
        default:
            break
        }
    }
    
    private func handleViewArticle(_ activity: NSUserActivity) {
        guard let id = activity.userInfo?["articleID"] as? String else { return }
        pendingArticleID = id
        selectedTab = .home
    }
    
    private func handleSearch(_ activity: NSUserActivity) {
        guard let query = activity.userInfo?["searchQuery"] as? String else { return }
        searchQuery = query
        selectedTab = .search
    }
    
    private func handleViewProfile(_ activity: NSUserActivity) {
        selectedTab = .profile
    }
    
    private func handleSpotlightTap(_ activity: NSUserActivity) {
        guard let id = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return }
        pendingArticleID = id
        selectedTab = .home
    }
    
    private func handleUniversalLink(_ url: URL) {
        handle(url: url) // Reuse URL handling logic
    }
}

// URL helper extension
extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems
        else { return nil }
        
        return Dictionary(uniqueKeysWithValues:
            queryItems.compactMap { item in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )
    }
}


// === 10b. Reusable Activity Modifier ===

struct ActivityModifier: ViewModifier {
    let activityType: String
    let title: String
    let userInfo: [String: Any]
    var isSearchable: Bool = true
    var isHandoff: Bool = true
    var isPrediction: Bool = true
    var keywords: Set<String> = []
    var webURL: URL? = nil
    var description: String? = nil
    
    func body(content: Content) -> some View {
        content.userActivity(activityType) { activity in
            activity.title = title
            activity.userInfo = userInfo
            activity.isEligibleForSearch = isSearchable
            activity.isEligibleForHandoff = isHandoff
            activity.isEligibleForPrediction = isPrediction
            activity.keywords = keywords
            activity.webpageURL = webURL
            
            if isSearchable {
                let attrs = CSSearchableItemAttributeSet(contentType: .text)
                attrs.title = title
                attrs.contentDescription = description
                attrs.keywords = Array(keywords)
                activity.contentAttributeSet = attrs
            }
            
            if let id = userInfo["id"] as? String {
                activity.persistentIdentifier = id
            }
        }
    }
}

extension View {
    func advertiseActivity(
        type: String,
        title: String,
        userInfo: [String: Any],
        keywords: Set<String> = [],
        webURL: URL? = nil,
        description: String? = nil,
        handoff: Bool = true,
        search: Bool = true,
        siri: Bool = true
    ) -> some View {
        modifier(ActivityModifier(
            activityType: type,
            title: title,
            userInfo: userInfo,
            isSearchable: search,
            isHandoff: handoff,
            isPrediction: siri,
            keywords: keywords,
            webURL: webURL,
            description: description
        ))
    }
}

// Sử dụng:
struct CleanArticleView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            Text(article.content)
        }
        // 1 dòng modifier thay vì configure 10+ properties
        .advertiseActivity(
            type: ActivityTypes.viewArticle,
            title: article.title,
            userInfo: ["articleID": article.id, "articleTitle": article.title],
            keywords: Set(article.tags),
            webURL: URL(string: "https://myapp.com/article/\(article.id)"),
            description: String(article.content.prefix(200))
        )
    }
}


// === 10c. Spotlight Index Manager ===

@Observable
final class SearchIndexManager {
    
    func indexArticle(_ article: Article) {
        let activity = NSUserActivity(activityType: ActivityTypes.viewArticle)
        activity.title = article.title
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.persistentIdentifier = article.id
        activity.userInfo = ["articleID": article.id, "articleTitle": article.title]
        
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = article.title
        attrs.contentDescription = String(article.content.prefix(300))
        attrs.keywords = article.tags
        attrs.identifier = article.id
        attrs.relatedUniqueIdentifier = article.id
        activity.contentAttributeSet = attrs
        
        activity.becomeCurrent()
    }
    
    func removeArticle(id: String) {
        // Remove từ Spotlight index
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [id]
        ) { _ in }
        
        // Remove từ Siri suggestions
        NSUserActivity.deleteSavedUserActivities(
            withPersistentIdentifiers: [id]
        ) { }
    }
    
    func removeAllArticles() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: ["articles"]
        ) { _ in }
    }
    
    func batchIndex(_ articles: [Article]) {
        let items = articles.map { article in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = article.title
            attrs.contentDescription = String(article.content.prefix(300))
            attrs.keywords = article.tags
            
            return CSSearchableItem(
                uniqueIdentifier: article.id,
                domainIdentifier: "articles",
                attributeSet: attrs
            )
        }
        
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("Batch index error: \(error)") }
        }
    }
}


// ╔══════════════════════════════════════════════════════════╗
// ║  11. COMMON PITFALLS & BEST PRACTICES                    ║
// ╚══════════════════════════════════════════════════════════╝

// ❌ PITFALL 1: Quên khai báo NSUserActivityTypes trong Info.plist
//    .userActivity("com.myapp.viewArticle") → app CRASH runtime
//    ✅ FIX: Info.plist > NSUserActivityTypes > thêm TẤT CẢ activity types

// ❌ PITFALL 2: userInfo chứa non-plist types
//    activity.userInfo = ["date": Date()] // Date KHÔNG phải plist type!
//    → Handoff thất bại silently
//    ✅ FIX: Chỉ dùng: String, Int, Double, Bool, Data, Array, Dictionary
//            Convert Date → TimeInterval hoặc ISO8601 String

// ❌ PITFALL 3: Quên persistentIdentifier cho Spotlight
//    → Mỗi lần view appear → index MỚI → duplicate results
//    ✅ FIX: activity.persistentIdentifier = uniqueID
//            Spotlight dùng ID để update thay vì duplicate

// ❌ PITFALL 4: .onContinueUserActivity ở view sai
//    Đặt handler ở child view đã bị destroy → không nhận activity
//    ✅ FIX: Đặt ở ROOT view (ContentView hoặc App struct)
//            để luôn sẵn sàng nhận

// ❌ PITFALL 5: Handoff data quá lớn
//    userInfo chứa full article content (10KB+) → chậm, có thể fail
//    ✅ FIX: Chỉ gửi ID + metadata nhỏ
//            Device nhận fetch full data từ API/iCloud

// ❌ PITFALL 6: Không test trên device thật
//    Simulator không hỗ trợ Handoff, Spotlight test hạn chế
//    ✅ FIX: Test Handoff trên 2 devices thật cùng Apple ID
//            Test Spotlight: search trên Home Screen sau khi index

// ❌ PITFALL 7: webpageURL bị bỏ qua
//    Không set webpageURL → device không có app không mở được gì
//    ✅ FIX: LUÔN set webpageURL cho Handoff activities
//            → Safari mở trang web nếu device không có app

// ❌ PITFALL 8: Siri suggestions không xuất hiện
//    isEligibleForPrediction = true nhưng không thấy suggestions
//    → Siri cần THỜI GIAN để học pattern
//    ✅ FIX: Kiên nhẫn, thực hiện activity nhiều lần
//            Dùng suggestedInvocationPhrase cho Siri voice

// ✅ BEST PRACTICES:
// 1. Info.plist: khai báo TẤT CẢ activity types
// 2. userInfo: CHỈ plist-compatible types, giữ NHỎ
// 3. persistentIdentifier: unique ID cho mỗi content item
// 4. webpageURL: LUÔN set cho Handoff (Safari fallback)
// 5. CSSearchableItemAttributeSet: rich metadata cho Spotlight
// 6. keywords: tag content để Spotlight tìm thấy
// 7. suggestedInvocationPhrase: cho Siri voice shortcuts
// 8. Centralized DeepLinkManager: 1 nơi handle tất cả activities
// 9. Reusable ViewModifier: .advertiseActivity() cho clean code
// 10. .onContinueUserActivity ở ROOT view
// 11. Clean up: remove index khi content bị xoá
// 12. Test trên device thật: Handoff, Spotlight, Siri
```

---

`.userActivity` là cầu nối giữa SwiftUI và NSUserActivity — hệ thống mạnh mẽ của Apple cho Handoff, Spotlight indexing, Siri Shortcuts, và Universal Links. Mình sẽ giải thích toàn bộ.Mình đã tổng hợp toàn bộ kiến thức `.userActivity` trong 11 phần. Đây là những điểm cốt lõi:

**NSUserActivity** trả lời câu hỏi "user đang làm gì?" — và thông tin đó được dùng cho **5 mục đích** khác nhau: Handoff (chuyển sang device khác), Spotlight (tìm kiếm iOS), Siri Shortcuts (gợi ý hành động), Universal Links (deep linking), và State Restoration.

**Hai modifier chính** hoạt động theo cặp:

- **`.userActivity(type) { activity in }`** — **Advertise**: "user đang xem article X". SwiftUI tự tạo activity khi view appear, gọi update closure, và invalidate khi disappear.
- **`.onContinueUserActivity(type) { activity in }`** — **Receive**: nhận activity từ Handoff/Spotlight/Siri rồi navigate đến đúng content.

**Bốn phần giá trị nhất cho production:**

**Phần 5 — Spotlight Search**: `isEligibleForSearch = true` + `CSSearchableItemAttributeSet` (title, description, keywords, thumbnail) → nội dung app xuất hiện trong iOS Search. `persistentIdentifier` là key — không có nó thì mỗi lần view appear tạo duplicate index.

**Phần 8 — onOpenURL vs onContinueUserActivity**: Hai cơ chế deep linking khác nhau mà production app cần **cả hai**. `.onOpenURL` cho URL schemes + widgets, `.onContinueUserActivity` cho Handoff + Spotlight + Siri. Thêm `CSSearchableItemActionType` để bắt tap trên Spotlight results.

**Phần 10a — Centralized DeepLinkManager**: Pattern chuẩn — một `@Observable` class handle tất cả activity types + URL schemes tại một chỗ, điều hướng qua `selectedTab` + `navigationPath`. Root view chỉ cần forward events vào manager.

**Phần 10b — Reusable Activity Modifier**: `.advertiseActivity()` ViewModifier gom 10+ property configurations thành 1 dòng modifier. Mỗi detail view chỉ cần 1 modifier thay vì configure NSUserActivity thủ công.

**Pitfall #1 quan trọng nhất**: Activity type **phải khai báo trong Info.plist** `NSUserActivityTypes` — thiếu sẽ crash runtime. Đây là lỗi phổ biến nhất vì Xcode không warning lúc compile.

Huy muốn mình đi tiếp sang chủ đề nào khác không?
