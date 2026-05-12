import Foundation
import Combine

@MainActor
final class SearchViewModel: UDFViewModel {
    
    // MARK: - State
    struct State {
        var searchText: String = ""
        var searchHistory: [String] = []
        var searchResult: Loadable<[Photo]> = .notRequested
    }
    
    // MARK: - Action
    enum Action {
        case loadHistory
        case updateSearchText(String)
        case performSearch(String)
        case clearSearch
    }
    
    @Published private(set) var state: State = State()
    private let photoInteractor: PhotoInteractorProtocol //
    
    init(photoInteractor: PhotoInteractorProtocol) {
        self.photoInteractor = photoInteractor
    }
    
    // MARK: - Dispatch
    func send(_ action: Action) {
        switch action {
        case .loadHistory:
            Task { await fetchHistory() }
            
        case .updateSearchText(let text):
            state.searchText = text
            // Nếu người dùng xóa sạch ô tìm kiếm, hiển thị lại lịch sử
            if text.isEmpty {
                send(.clearSearch)
            }
            
        case .performSearch(let query):
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            
            Task {
                await saveKeyword(trimmed)
                await fetchHistory() // Cập nhật lại list lịch sử ngay lập tức
                await searchPhotos(query: trimmed)
            }
            
        case .clearSearch:
            state.searchResult = .notRequested
            Task { await fetchHistory() }
        }
    }
    
    // MARK: - Async/Await Logic
    private func fetchHistory() async {
        do {
            let history = try await photoInteractor.getSearchHistory() //
            state.searchHistory = history
        } catch {
            print("Failed to load history: \(error)")
        }
    }
    
    private func saveKeyword(_ keyword: String) async {
        try? await photoInteractor.saveSearchKeyword(keyword) //
    }
    
    private func searchPhotos(query: String) async {
        state.searchResult = .isLoading(last: state.searchResult.value, cancelBag: CancelBag())
        do {
            let result = try await photoInteractor.searchPhotos(query: query, page: 1, perPage: 30) //
            state.searchResult = .loaded(result.results)
        } catch {
            state.searchResult = .failed(error)
        }
    }
}
