import SwiftUI
import Combine

@MainActor
final class PhotosViewModel: UDFViewModel {

    // MARK: - State

    struct State {
        var photos: Loadable<[Photo]> = .notRequested
        var isLoadingMore: Bool = false
        var canLoadMore: Bool = true
    }

    // MARK: - Action

    enum Action {
        case loadPhotos
        case refreshPhotos
        case loadMore
    }

    @Published private(set) var state: State

    // Dependencies
    private let photosInteractor: PhotosInteractorProtocol
    private let perPage = 30
    private var page = 1

    init(photosInteractor: PhotosInteractorProtocol) {
        self.photosInteractor = photosInteractor
        self.state = State()
    }

    // MARK: - Dispatch Action

    func send(_ action: Action) {
        switch action {
        case .loadPhotos:
            guard state.photos == .notRequested else { return }
            Task { await fetchPhotos() }

        case .refreshPhotos:
            Task { await fetchPhotos() }

        case .loadMore:
            Task { await loadMore() }
        }
    }

    // MARK: - Async/Await Logic

    /// Load the first page (for first-time use and pull-to-refresh)
    private func fetchPhotos() async {
        page = 1
        state.canLoadMore = true
        state.photos = .isLoading(last: state.photos.value, cancelBag: CancelBag())

        do {
            let fetched = try await photosInteractor.fetchPhotos(page: page, perPage: perPage)
            state.photos = .loaded(fetched)
            state.canLoadMore = fetched.count == perPage
            page = 2
        } catch {
            state.photos = .failed(error)
        }
    }

    /// Load the next page and append it to the current list.
    private func loadMore() async {
        guard case let .loaded(current) = state.photos,
              !state.isLoadingMore,
              state.canLoadMore else { return }

        state.isLoadingMore = true
        defer { state.isLoadingMore = false }

        do {
            let next = try await photosInteractor.fetchPhotos(page: page, perPage: perPage)
            state.photos = .loaded(current + next)
            state.canLoadMore = next.count == perPage
            page += 1
        } catch {
            // Keep the existing list if the next page return error.
            state.canLoadMore = false
        }
    }
}
