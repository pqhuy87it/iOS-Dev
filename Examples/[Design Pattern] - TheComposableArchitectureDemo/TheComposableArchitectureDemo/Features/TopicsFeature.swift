import ComposableArchitecture
import Foundation

@Reducer
struct TopicsFeature {
    @ObservableState
    struct State: Equatable {
        var isLoading: Bool = false
        var errorMessage: String? = nil
        
        var heroTopic: Topic? = nil
        // IdentifiedArray là một kiểu dữ liệu siêu tối ưu của TCA dành cho danh sách
        var rows: IdentifiedArrayOf<TopicRowFeature.State> = []
    }
    
    enum Action {
        case onAppear
        case fetchTopicsResponse(Result<[Topic], Error>)
        // Action này dùng để hứng các sự kiện từ các dòng con (Row) gửi lên
        case row(IdentifiedActionOf<TopicRowFeature>)
    }
    
    @Dependency(\.unsplashClient) var unsplashClient
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.heroTopic == nil && state.rows.isEmpty else { return .none }
                
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await send(.fetchTopicsResponse(
                        Result { try await unsplashClient.fetchTopics(1, 10) }
                    ))
                }
                
            case let .fetchTopicsResponse(.success(topics)):
                state.isLoading = false
                
                if let firstTopic = topics.first {
                    state.heroTopic = firstTopic
                    
                    // Lấy các topic còn lại, biến chúng thành State của Feature con
                    let remainingTopics = topics.dropFirst()
                    state.rows = IdentifiedArray(
                        uniqueElements: remainingTopics.map { TopicRowFeature.State(topic: $0) }
                    )
                }
                return .none
                
            case let .fetchTopicsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .row:
                // Reducer cha không cần can thiệp trực tiếp vào việc con load ảnh
                return .none
            }
        }
        // KẾT NỐI CHA VÀ CON Ở ĐÂY:
        .forEach(\.rows, action: \.row) {
            TopicRowFeature()
        }
    }
}
