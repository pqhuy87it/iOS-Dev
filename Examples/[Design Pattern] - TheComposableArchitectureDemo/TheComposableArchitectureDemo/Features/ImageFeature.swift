import ComposableArchitecture
import UIKit
import Foundation

@Reducer
struct ImageFeature {
    @ObservableState
    struct State: Equatable {
        let url: URL
        var image: UIImage? = nil
        var isLoading: Bool = false
        var errorMessage: String? = nil
    }
    
    enum Action {
        case loadImage
        case imageResponse(Result<UIImage, Error>)
    }
    
    @Dependency(\.imagesRepository) var imagesRepository
    
    // 1. Thay đổi 'some ReducerOf<Self>' thành 'some Reducer<State, Action>'
    var body: some Reducer<State, Action> {
        
        // 2. Chỉ định rõ kiểu cho Reduce
        Reduce<State, Action> { state, action in
            switch action {
            case .loadImage:
                guard state.image == nil else { return .none }
                
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [url = state.url] send in
                    await send(.imageResponse(
                        Result { try await imagesRepository.loadImage(url: url) }
                    ))
                }
                
            case let .imageResponse(.success(uiImage)):
                state.isLoading = false
                state.image = uiImage
                return .none
                
            case let .imageResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
