import SwiftUI
import Combine

@MainActor
final class ImageViewModel: UDFViewModel {
    
    // MARK: - State & Action
    struct State {
        var image: Loadable<UIImage> = .notRequested
    }
    
    enum Action {
        case loadImage(URL?)
    }
    
    @Published private(set) var state: State = State()
    
    private let interactor: ImagesInteractorProtocol
    
    init(interactor: ImagesInteractorProtocol) {
        self.interactor = interactor
    }
    
    // MARK: - Dispatch
    func send(_ action: Action) {
        switch action {
        case .loadImage(let url):
            guard let url = url else {
                state.image = .notRequested
                return
            }
            guard case .notRequested = state.image else { return }
            Task { await fetchImage(url: url) }
        }
    }
    
    private func fetchImage(url: URL) async {
        // Đặt state thành loading
        state.image = .isLoading(last: state.image.value, cancelBag: CancelBag())
        
        do {
            let uiImage = try await interactor.loadImage(url: url)
            state.image = .loaded(uiImage)
        } catch {
            state.image = .failed(error)
        }
    }
}
