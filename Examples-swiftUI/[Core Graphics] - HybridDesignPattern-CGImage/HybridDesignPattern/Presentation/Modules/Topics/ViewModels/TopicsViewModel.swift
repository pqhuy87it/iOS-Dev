import Foundation
import Combine

@MainActor
final class TopicsViewModel: UDFViewModel {
    
    // MARK: - State
    
    struct State {
        var topics: Loadable<[Topic]> = .notRequested
    }
    
    // MARK: - Action
    
    enum Action {
        case loadTopics
        case refreshTopics
    }
    
    @Published private(set) var state: State = State()
    private let topicsInteractor: TopicsInteractorProtocol
    
    init(topicsInteractor: TopicsInteractorProtocol) {
        self.topicsInteractor = topicsInteractor
    }
    
    // MARK: - Dispatch Action
    
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
            let fetched = try await topicsInteractor.fetchTopics(page: 1, perPage: 10)
            state.topics = .loaded(fetched)
        } catch {
            state.topics = .failed(error)
        }
    }
}
