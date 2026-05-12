import SwiftUI
import Combine

struct AppState: Equatable {
//    var routing = ViewRouting()
    var system = System()
}

//extension AppState {
//    struct ViewRouting: Equatable {
//        var countriesList = PhotosListView.Routing()
//    }
//}

extension AppState {
    struct System: Equatable {
        var isActive: Bool = false
        var keyboardHeight: CGFloat = 0
    }
}
