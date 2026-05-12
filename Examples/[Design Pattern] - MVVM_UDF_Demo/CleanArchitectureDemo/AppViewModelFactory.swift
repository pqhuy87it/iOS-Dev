import Combine

@MainActor final class AppViewModelFactory: ViewModelFactory, ObservableObject {
    /// Chỉ giữ reference tới Interactors, Factory không cần biết về View
    private let interactors: DIContainer.Interactors

    init(interactors: DIContainer.Interactors) {
        self.interactors = interactors
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
        return SearchViewModel(photoInteractor: interactors.photos)
    }
}
