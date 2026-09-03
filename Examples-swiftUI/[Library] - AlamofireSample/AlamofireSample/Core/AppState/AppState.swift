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

    enum AppTab: Int, Equatable, Hashable, CaseIterable {
        case home, topics, search
    }
}

extension AppState {
    struct System: Equatable {
        var isActive: Bool = true
        var keyboardHeight: CGFloat = 0
    }
}
