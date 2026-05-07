import ComposableArchitecture
import Foundation

@Reducer
struct SearchFeature {
    @ObservableState
    struct State: Equatable {
        var searchText: String = ""
        var searchHistory: [String] = []
        var photos: [Photo] = []
        var isLoading: Bool = false
        var errorMessage: String? = nil
        
        // Trạng thái: Nếu chưa có text và chưa có ảnh -> Hiện History
        var shouldShowHistory: Bool {
            searchText.isEmpty || (!isLoading && photos.isEmpty && errorMessage == nil)
        }
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>) // Bắt buộc phải có để dùng @Bindable
        case onAppear
        case loadHistory
        case historyResponse(Result<[String], Error>)
        case performSearch(String)
        case searchResponse(Result<SearchResult, Error>)
        case clearResults
    }
    
    @Dependency(\.unsplashClient) var unsplashClient
    @Dependency(\.searchDatabaseClient) var dbClient
    
    var body: some Reducer<State, Action> {
        // Tự động xử lý các biến đổi UI được bind (như searchText)
        BindingReducer()
        
        Reduce<State, Action> { state, action in
            switch action {
            // Lắng nghe khi searchText bị thay đổi
            case .binding(\.searchText):
                if state.searchText.isEmpty {
                    return .send(.clearResults) // Xoá trắng ô search -> Hiện lại history
                }
                return .none
                
            case .binding:
                return .none
                
            case .onAppear, .loadHistory:
                return .run { send in
                    await send(.historyResponse(
                        Result { try await dbClient.getHistory() }
                    ))
                }
                
            case let .historyResponse(.success(history)):
                state.searchHistory = history
                return .none
                
            case .historyResponse(.failure):
                return .none // Lỗi DB thì cứ bỏ qua, không cần crash app
                
            case let .performSearch(keyword):
                let trimmed = keyword.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return .none }
                
                state.searchText = trimmed
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    // 1. Lưu vào Database (chạy ngầm)
                    try? await dbClient.saveKeyword(trimmed)
                    
                    // 2. Yêu cầu Reducer load lại history để cập nhật List UI
                    await send(.loadHistory)
                    
                    // 3. Gọi API search
                    await send(.searchResponse(
                        Result { try await unsplashClient.searchPhotos(trimmed, 1, 30) }
                    ))
                }
                
            case let .searchResponse(.success(result)):
                state.isLoading = false
                state.photos = result.results
                return .none
                
            case let .searchResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .clearResults:
                state.photos = []
                state.isLoading = false
                state.errorMessage = nil
                return .send(.loadHistory)
            }
        }
    }
}
