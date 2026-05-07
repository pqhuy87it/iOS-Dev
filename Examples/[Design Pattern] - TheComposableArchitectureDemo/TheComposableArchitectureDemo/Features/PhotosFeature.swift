import ComposableArchitecture
import Foundation

@Reducer
struct PhotosFeature {
    // 1. STATE: Chứa dữ liệu giao diện
    @ObservableState
    struct State: Equatable {
        var photos: [Photo] = []
        var isLoading: Bool = false
        var errorMessage: String? = nil
    }
    
    // 2. ACTION: Các sự kiện người dùng hoặc hệ thống
    enum Action {
        case onAppear
        case fetchPhotosResponse(Result<[Photo], Error>)
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
                
                // Gọi Side Effect (API)
                return .run { send in
                    await send(.fetchPhotosResponse(
                        Result { try await unsplashClient.fetchPhotos(1, 30) }
                    ))
                }
                
            case let .fetchPhotosResponse(.success(photos)):
                state.isLoading = false
                state.photos = photos
                return .none
                
            case let .fetchPhotosResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
