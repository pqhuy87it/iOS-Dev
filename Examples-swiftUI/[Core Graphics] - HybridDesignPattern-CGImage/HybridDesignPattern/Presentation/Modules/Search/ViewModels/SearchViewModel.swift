import Combine
import Foundation

@MainActor
final class SearchViewModel: UDFViewModel {
    
    // MARK: - State

    struct State {
        var searchText: String = ""
        var searchHistory: [String] = []
        var searchResult: Loadable<[Photo]> = .notRequested
        /// Phản ánh AppState.system.isActive — dùng để UI biết app đang ở foreground hay background
        var isAppActive: Bool = true
        var isLoadingMore: Bool = false
        var canLoadMore: Bool = false
    }

    // MARK: - Action

    enum Action {
        case loadHistory
        case updateSearchText(String)
        case performSearch(String)
        case loadMore
        case clearSearch
    }

    @Published private(set) var state: State = .init()
    private let searchInteractor: SearchInteractorProtocol
    private let appState: Store<AppState>
    private var cancellables = Set<AnyCancellable>()

    private let perPage = 30
    private var page = 1
    private var currentQuery = ""

    init(searchInteractor: SearchInteractorProtocol, appState: Store<AppState>) {
        self.searchInteractor = searchInteractor
        self.appState = appState

        appState
            .updates(for: \.system.isActive)
            .receive(on: RunLoop.main)
            .sink { [weak self] isActive in
                guard let self else { return }
                self.state.isAppActive = isActive
                if isActive {
                    Task { await self.fetchHistory() }
                } else {
                    self.state.searchResult = .notRequested
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Dispatch Action

    func send(_ action: Action) {
        switch action {
        case .loadHistory:
            Task { await fetchHistory() }

        case .updateSearchText(let text):
            state.searchText = text
            if text.isEmpty {
                send(.clearSearch)
            }

        case .performSearch(let query):
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }

            Task {
                await saveKeyword(trimmed)
                await fetchHistory()
                await searchPhotos(query: trimmed)
            }

        case .loadMore:
            Task { await loadMore() }

        case .clearSearch:
            state.searchResult = .notRequested
            state.canLoadMore = false
            currentQuery = ""
            Task { await fetchHistory() }
        }
    }

    // MARK: - Async Logic

    private func fetchHistory() async {
        do {
            let history = try await searchInteractor.getSearchHistory()
            state.searchHistory = history
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    private func saveKeyword(_ keyword: String) async {
        try? await searchInteractor.saveSearchKeyword(keyword)
    }

    private func searchPhotos(query: String) async {
        currentQuery = query
        page = 1
        state.canLoadMore = false
        state.searchResult = .isLoading(last: state.searchResult.value,
                                        cancelBag: CancelBag())
        do {
            let result = try await searchInteractor.searchPhotos(query: query,
                                                                 page: page,
                                                                 perPage: perPage)
            state.searchResult = .loaded(result.results)
            state.canLoadMore = page < result.totalPages
            page = 2
        } catch {
            state.searchResult = .failed(error)
        }
    }

    /// Tải trang kế tiếp cho từ khóa hiện tại và nối vào kết quả.
    private func loadMore() async {
        guard case let .loaded(current) = state.searchResult,
              !state.isLoadingMore,
              state.canLoadMore,
              !currentQuery.isEmpty else { return }

        state.isLoadingMore = true
        defer { state.isLoadingMore = false }

        do {
            let result = try await searchInteractor.searchPhotos(query: currentQuery,
                                                                 page: page,
                                                                 perPage: perPage)
            state.searchResult = .loaded(current + result.results)
            state.canLoadMore = page < result.totalPages
            page += 1
        } catch {
            state.canLoadMore = false
        }
    }
}
