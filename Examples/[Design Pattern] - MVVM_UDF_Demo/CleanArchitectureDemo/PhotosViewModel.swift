import SwiftUI
import Combine

@MainActor
final class PhotosViewModel: UDFViewModel {
    
    // MARK: - UDF State & Action
    struct State {
        var photos: Loadable<[Photo]> = .notRequested
    }
    
    enum Action {
        case loadPhotos
        case refreshPhotos
    }
    
    @Published private(set) var state: State
    
    // Dependencies (Sử dụng Interactor đã có từ Clean Architecture)
    private let photoInteractor: PhotoInteractorProtocol
    
    init(photoInteractor: PhotoInteractorProtocol) {
        self.photoInteractor = photoInteractor
        self.state = State()
    }
    
    // MARK: - Intent / Dispatch Action
    func send(_ action: Action) {
        switch action {
        case .loadPhotos:
            guard state.photos == .notRequested else { return }
            Task { await fetchPhotos() }
            
        case .refreshPhotos:
            Task { await fetchPhotos() }
        }
    }
    
    // MARK: - Async/Await Logic
    private func fetchPhotos() async {
        // Chuyển state sang loading
        state.photos = .isLoading(last: state.photos.value, cancelBag: CancelBag())
        
        do {
            let fetchedPhotos = try await photoInteractor.fetchPhotos(page: 1, perPage: 30)
            state.photos = .loaded(fetchedPhotos)
        } catch {
            state.photos = .failed(error)
        }
    }
}
