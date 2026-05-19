import Combine

@MainActor final class AppViewModelFactory: ViewModelFactory, ObservableObject {
    private let interactors: DIContainer.Interactors
    private let appState: Store<AppState>

    init(interactors: DIContainer.Interactors, appState: Store<AppState>) {
        self.interactors = interactors
        self.appState = appState
    }

    func makePhotosViewModel() -> PhotosViewModel {
        return PhotosViewModel(photoInteractor: interactors.photos)
    }

    func makeImageViewModel() -> ImageViewModel {
        return ImageViewModel(interactor: interactors.images)
    }

    func makeTopicsViewModel() -> TopicsViewModel {
        return TopicsViewModel(photoInteractor: interactors.photos)
    }

    func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel {
        return TopicRowViewModel(topic: topic, photoInteractor: interactors.photos)
    }

    func makeSearchViewModel() -> SearchViewModel {
        return SearchViewModel(photoInteractor: interactors.photos, appState: appState)
    }
}
