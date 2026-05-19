import Foundation
import Combine

@MainActor
final class SearchViewModel: UDFViewModel {

    // MARK: - State
    struct State {
        var searchText: String = ""
        var searchHistory: [String] = []
        var searchResult: Loadable<[Photo]> = .notRequested
        // Phản ánh AppState.system.isActive — dùng để UI biết app đang ở foreground hay background
        var isAppActive: Bool = true
    }

    // MARK: - Action
    enum Action {
        case loadHistory
        case updateSearchText(String)
        case performSearch(String)
        case clearSearch
    }

    @Published private(set) var state: State = State()
    private let photoInteractor: PhotoInteractorProtocol
    private let appState: Store<AppState>
    private var cancellables = Set<AnyCancellable>()

    init(photoInteractor: PhotoInteractorProtocol, appState: Store<AppState>) {
        self.photoInteractor = photoInteractor
        self.appState = appState

        // Subscribe AppState.system.isActive:
        // - Khi app trở lại foreground (isActive = true) → tự động reload lịch sử tìm kiếm
        // - Khi app vào background (isActive = false) → xoá kết quả search đang hiển thị
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

    // MARK: - Dispatch
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

        case .clearSearch:
            state.searchResult = .notRequested
            Task { await fetchHistory() }
        }
    }

    // MARK: - Async Logic
    private func fetchHistory() async {
        do {
            let history = try await photoInteractor.getSearchHistory()
            state.searchHistory = history
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    private func saveKeyword(_ keyword: String) async {
        try? await photoInteractor.saveSearchKeyword(keyword)
    }

    private func searchPhotos(query: String) async {
        state.searchResult = .isLoading(last: state.searchResult.value,
                                        cancelBag: CancelBag())
        do {
            let result = try await photoInteractor.searchPhotos(query: query,
                                                                page: 1,
                                                                perPage: 30)
            state.searchResult = .loaded(result.results)
        } catch {
            state.searchResult = .failed(error)
        }
    }
}
