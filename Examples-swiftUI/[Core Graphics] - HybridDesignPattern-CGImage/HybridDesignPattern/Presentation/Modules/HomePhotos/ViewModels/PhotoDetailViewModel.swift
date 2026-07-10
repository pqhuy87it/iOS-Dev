import SwiftUI
import Combine

@MainActor
final class PhotoDetailViewModel: UDFViewModel {

    // MARK: - State
    
    struct State {
        let photo: Photo
    }

    // MARK: - Action
    
    enum Action {
        // TODO: need implement
    }

    @Published private(set) var state: State

    init(photo: Photo) {
        self.state = State(photo: photo)
    }

    // MARK: - Dispatch Action
    
    func send(_ action: Action) {
        // TODO: need implement
    }

    // MARK: - Derived display data
    
    var imageURL: URL { state.photo.urls.regular }
    var authorName: String { state.photo.user.name ?? state.photo.user.username }
    var description: String? { state.photo.description ?? state.photo.altDescription }
    var sizeText: String { "Original size: \(state.photo.width) x \(state.photo.height)" }
}
