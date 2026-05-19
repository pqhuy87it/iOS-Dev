import Foundation
import Combine

@MainActor
final class TopicRowViewModel: UDFViewModel {
    struct State {
        var photos: Loadable<[Photo]> = .notRequested
    }
    
    enum Action {
        case loadPhotos
    }
    
    @Published private(set) var state: State = State()
    private let topic: Topic
    private let photoInteractor: PhotoInteractorProtocol
    
    init(topic: Topic, photoInteractor: PhotoInteractorProtocol) {
        self.topic = topic
        self.photoInteractor = photoInteractor
    }
    
    func send(_ action: Action) {
        switch action {
        case .loadPhotos:
            guard state.photos == .notRequested else { return }
            Task { await fetchPhotos() }
        }
    }
    
    private func fetchPhotos() async {
        state.photos = .isLoading(last: state.photos.value, cancelBag: CancelBag())
        do {
            let fetched = try await photoInteractor.fetchTopicPhotos(slug: topic.slug, page: 1, perPage: 10)
            state.photos = .loaded(fetched)
        } catch {
            state.photos = .failed(error)
        }
    }
}
