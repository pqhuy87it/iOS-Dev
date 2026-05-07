import ComposableArchitecture
import Foundation

@Reducer
struct TopicRowFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        var id: String { topic.id } // Phải có id để làm việc với IdentifiedArray
        let topic: Topic
        var photos: [Photo] = []
        var isLoading: Bool = false
    }
    
    enum Action {
        case onAppear
        case fetchPhotosResponse(Result<[Photo], Error>)
    }
    
    @Dependency(\.unsplashClient) var unsplashClient
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Nếu đã có ảnh rồi thì không load lại khi scroll qua lại
                guard state.photos.isEmpty else { return .none }
                
                state.isLoading = true
                return .run { [slug = state.topic.slug] send in
                    await send(.fetchPhotosResponse(
                        Result { try await unsplashClient.fetchTopicPhotos(slug, 1, 10) }
                    ))
                }
                
            case let .fetchPhotosResponse(.success(photos)):
                state.isLoading = false
                state.photos = photos
                return .none
                
            case .fetchPhotosResponse(.failure):
                state.isLoading = false
                // Bỏ qua xử lý lỗi chi tiết cho từng dòng để UI đỡ rối, có thể hiện placeholder
                return .none
            }
        }
    }
}
