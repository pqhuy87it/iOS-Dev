import SwiftUI
import Combine

@MainActor
final class ImageViewModel: UDFViewModel {
    
    // MARK: - State

    struct State {
        let imageURL: URL
        var image: Loadable<UIImage> = .notRequested
    }
    
    // MARK: - Action

    enum Action {
        case onAppear
    }

    @Published private(set) var state: State

    private let interactor: ImagesInteractorProtocol

    init(imageURL: URL, interactor: ImagesInteractorProtocol) {
        self.interactor = interactor
        self.state = State(imageURL: imageURL)
    }

    // MARK: - Dispatch

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            guard case .notRequested = state.image else { return }
            Task { await fetchImage(url: state.imageURL) }
        }
    }
    
    private func fetchImage(url: URL) async {
        state.image = .isLoading(last: state.image.value, cancelBag: CancelBag())
        
        do {
            let uiImage = try await interactor.loadImage(url: url)
            state.image = .loaded(uiImage)
        } catch {
            state.image = .failed(error)
        }
    }
}
