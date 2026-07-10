import Combine
import Foundation

@MainActor
final class TopicRowViewModel: UDFViewModel {
    
    // MARK: - State
    
    struct State {
        var photos: Loadable<[Photo]> = .notRequested
    }
    
    // MARK: - Action
    
    enum Action {
        case loadPhotos
    }
    
    @Published private(set) var state: State = .init()
    private let topic: Topic
    private let topicsInteractor: TopicsInteractorProtocol

    init(topic: Topic, topicsInteractor: TopicsInteractorProtocol) {
        self.topic = topic
        self.topicsInteractor = topicsInteractor
    }
    
    // MARK: - Dispatch Action
    
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
            let fetched = try await topicsInteractor.fetchTopicPhotos(slug: topic.slug, page: 1, perPage: 10)
            state.photos = .loaded(fetched)
        } catch {
            state.photos = .failed(error)
        }
    }
}
