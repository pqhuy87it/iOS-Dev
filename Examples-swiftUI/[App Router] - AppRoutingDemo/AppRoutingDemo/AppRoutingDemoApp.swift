import SwiftUI
import Observation

// MARK: - 1. MOCK MODELS
// Tạo các struct giả lập để code không bị lỗi thiếu model
public struct Account: Hashable, Identifiable {
    public let id: String
    public let displayName: String
}

public struct Status: Hashable, Identifiable {
    public let id: String
    public let content: String
    public let account: Account
}

public enum Visibility: Hashable, Codable {
    case publicVis, privateVis, unlisted
}

// MARK: - 2. ĐỊNH NGHĨA DESTINATIONS
// Rút gọn một số case từ code của bạn để tập trung vào luồng chính
public enum RouterDestination: Hashable {
    case accountDetail(id: String)
    case statusDetail(id: String)
    case hashTag(tag: String)
    case followers(id: String)
}

public enum SheetDestination: Identifiable, Hashable {
    case newStatusEditor(visibility: Visibility)
    case settings
    case about
    
    public var id: String {
        switch self {
        case .newStatusEditor: return "statusEditor"
        case .settings: return "settings"
        case .about: return "about"
        }
    }
}

// MARK: - 3. ROUTER PATH (Trình điều hướng)
@MainActor
@Observable
public class RouterPath {
    public var path: [RouterDestination] = []
    public var presentedSheet: SheetDestination?
    
    public init() {}
    
    // Hàm Push màn hình
    public func navigate(to destination: RouterDestination) {
        path.append(destination)
    }
    
    // Hàm Pop về màn hình trước
    public func goBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    // Hàm Pop về Root
    public func popToRoot() {
        path.removeAll()
    }
}

// MARK: - 4. ỨNG DỤNG & CẤU HÌNH ROOT VIEW
@main
struct SocialApp: App {
    // Khởi tạo Router 1 lần duy nhất ở cấp cao nhất
    @State private var router = RouterPath()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(router) // Bơm router vào Environment để mọi View đều gọi được
        }
    }
}

// MARK: - 5. MAIN TAB VIEW (UI Chính)
struct MainTabView: View {
    @Environment(RouterPath.self) private var router
    
    var body: some View {
        // Dùng @Bindable để binding path và sheet với NavigationStack
        @Bindable var routerBindable = router
        
        NavigationStack(path: $routerBindable.path) {
            HomeFeedView()
                // Cấu hình Nơi nhận các Push (Destinations)
                .navigationDestination(for: RouterDestination.self) { destination in
                    switch destination {
                    case .accountDetail(let id):
                        AccountDetailView(accountId: id)
                    case .statusDetail(let id):
                        StatusDetailView(statusId: id)
                    case .hashTag(let tag):
                        Text("Hashtag: #\(tag)").font(.largeTitle)
                    case .followers(let id):
                        Text("Followers của \(id)")
                    }
                }
                // Cấu hình Nơi nhận các Modal/Sheets
                .sheet(item: $routerBindable.presentedSheet) { sheet in
                    switch sheet {
                    case .newStatusEditor(let visibility):
                        NewStatusView(visibility: visibility)
                    case .settings:
                        Text("Màn hình Cài đặt").font(.largeTitle)
                    case .about:
                        Text("Về ứng dụng").font(.largeTitle)
                    }
                }
        }
    }
}

// MARK: - 6. CÁC MÀN HÌNH DEMO (VIEWS)

struct HomeFeedView: View {
    @Environment(RouterPath.self) private var router
    
    var body: some View {
        List {
            Section("Push Navigation") {
                Button("Xem bài viết (Status ID: 101)") {
                    router.navigate(to: .statusDetail(id: "101"))
                }
                Button("Xem hồ sơ (Account ID: dev_iOS)") {
                    router.navigate(to: .accountDetail(id: "dev_iOS"))
                }
                Button("Khám phá Hashtag #SwiftUI") {
                    router.navigate(to: .hashTag(tag: "SwiftUI"))
                }
            }
            
            Section("Modal & Sheets") {
                Button("Viết bài mới") {
                    router.presentedSheet = .newStatusEditor(visibility: .publicVis)
                }
                Button("Mở Cài đặt") {
                    router.presentedSheet = .settings
                }
            }
        }
        .navigationTitle("Trang chủ")
    }
}

struct StatusDetailView: View {
    @Environment(RouterPath.self) private var router
    let statusId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Chi tiết bài viết: \(statusId)")
                .font(.headline)
            
            Button("Xem tác giả bài viết này") {
                // Thử điều hướng tiếp từ một màn hình con
                router.navigate(to: .accountDetail(id: "author_of_\(statusId)"))
            }
            
            Button("Về trang chủ (Pop to Root)") {
                router.popToRoot()
            }
        }
        .navigationTitle("Status")
    }
}

struct AccountDetailView: View {
    let accountId: String
    @Environment(RouterPath.self) private var router
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
            
            Text("Hồ sơ: \(accountId)")
                .font(.title)
            
            Button("Xem danh sách Follower") {
                router.navigate(to: .followers(id: accountId))
            }
        }
        .navigationTitle("Account")
    }
}

struct NewStatusView: View {
    @Environment(RouterPath.self) private var router
    let visibility: Visibility
    
    var body: some View {
        NavigationStack {
            Text("Đang soạn bài viết mới...")
                .navigationTitle("Tạo bài viết")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") {
                            // Đóng sheet bằng cách gán nil
                            router.presentedSheet = nil
                        }
                    }
                }
        }
    }
}
