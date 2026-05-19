import Foundation
import Combine

@MainActor
final class TopicsViewModel: UDFViewModel {
    struct State {
        var topics: Loadable<[Topic]> = .notRequested
    }
    
    enum Action {
        case loadTopics
        case refreshTopics
    }
    
    @Published private(set) var state: State = State()
    private let photoInteractor: PhotoInteractorProtocol
    
    init(photoInteractor: PhotoInteractorProtocol) {
        self.photoInteractor = photoInteractor
    }
    
    func send(_ action: Action) {
        switch action {
        case .loadTopics:
            guard state.topics == .notRequested else { return }
            Task { await fetchTopics() }
        case .refreshTopics:
            Task { await fetchTopics() }
        }
    }
    
    private func fetchTopics() async {
        state.topics = .isLoading(last: state.topics.value, cancelBag: CancelBag())
        do {
            let fetched = try await photoInteractor.fetchTopics(page: 1, perPage: 10)
            state.topics = .loaded(fetched)
        } catch {
            state.topics = .failed(error)
        }
    }
}
