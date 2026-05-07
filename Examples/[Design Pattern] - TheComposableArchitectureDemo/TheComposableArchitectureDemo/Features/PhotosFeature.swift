import ComposableArchitecture
import Foundation

@Reducer
struct PhotosFeature {
    // 1. STATE: Chứa dữ liệu giao diện
    @ObservableState
    struct State: Equatable {
        var photos: [Photo] = []
        var isLoading: Bool = false
        var isLoadingMore: Bool = false
        var canLoadMore: Bool = true
        var currentPage: Int = 1
        var errorMessage: String? = nil
    }

    // 2. ACTION: Các sự kiện người dùng hoặc hệ thống
    enum Action {
        case onAppear
        case loadMorePhotos
        case fetchPhotosResponse(Result<[Photo], Error>)
        case loadMorePhotosResponse(Result<[Photo], Error>)
    }

    // 3. DEPENDENCY: Gọi API
    @Dependency(\.unsplashClient) var unsplashClient

    // 4. REDUCE: Nơi xử lý logic và thay đổi State
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                state.currentPage = 1
                state.canLoadMore = true

                return .run { send in
                    await send(.fetchPhotosResponse(
                        Result { try await unsplashClient.fetchPhotos(1, 30) }
                    ))
                }

            case .loadMorePhotos:
                guard !state.isLoadingMore, state.canLoadMore else { return .none }
                state.isLoadingMore = true
                let nextPage = state.currentPage + 1

                return .run { send in
                    await send(.loadMorePhotosResponse(
                        Result { try await unsplashClient.fetchPhotos(nextPage, 30) }
                    ))
                }

            case let .fetchPhotosResponse(.success(photos)):
                state.isLoading = false
                state.photos = photos
                state.currentPage = 1
                state.canLoadMore = photos.count == 30
                return .none

            case let .fetchPhotosResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .loadMorePhotosResponse(.success(photos)):
                state.isLoadingMore = false
                state.photos += photos
                state.currentPage += 1
                state.canLoadMore = photos.count == 30
                return .none

            case let .loadMorePhotosResponse(.failure(error)):
                state.isLoadingMore = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
