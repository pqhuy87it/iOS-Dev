import SwiftUI
import Combine

struct AppState: Equatable {
    var routing = ViewRouting()
    var system = System()
}

extension AppState {
    struct ViewRouting: Equatable {
        var selectedTab: AppTab = .home
    }

    // Dùng làm giá trị selection cho TabView — hỗ trợ điều hướng tab theo kiểu UDF
    enum AppTab: Int, Equatable, Hashable, CaseIterable {
        case home, topics, search
    }
}

extension AppState {
    struct System: Equatable {
        // true khi app đang ở foreground, false khi vào background
        var isActive: Bool = true
        var keyboardHeight: CGFloat = 0
    }
}
