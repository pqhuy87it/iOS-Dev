import SwiftUI
import SwiftData
import Combine

struct DIContainer {
    let appState: Store<AppState>
    let interactors: Interactors

    init(appState: Store<AppState> = .init(AppState()), interactors: Interactors) {
        self.appState = appState
        self.interactors = interactors
    }

    init(appState: AppState, interactors: Interactors) {
        self.init(appState: Store<AppState>(appState),
                  interactors: interactors)
    }
}

extension DIContainer {
    struct WebRepositories {
        let images: ImagesWebRepositoryProtocol
        let unsplash: UnsplashWebRepositoryProtocol
    }
    
    struct DBRepositories {
        let searchDB: SearchDBRepositoryProtocol
    }
    
    struct Interactors {
        let images: ImagesInteractorProtocol
        let photos: PhotoInteractorProtocol

        static var stub: Self {
            .init(images: StubImagesInteractor(),
                  photos: StubPhotoInteractor())
        }
    }
}

extension EnvironmentValues {
    @Entry var injected: DIContainer = DIContainer(appState: AppState(),
                                                   interactors: .stub)
}

extension View {
    func inject(_ container: DIContainer) -> some View {
        return self
            .environment(\.injected, container)
    }
}
