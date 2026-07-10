import Foundation
import Combine

@MainActor final class AppViewModelFactory: ViewModelFactory, ObservableObject {
    private let interactors: DIContainer.Interactors
    private let appState: Store<AppState>

    init(interactors: DIContainer.Interactors, appState: Store<AppState>) {
        self.interactors = interactors
        self.appState = appState
    }

    func makePhotosViewModel() -> PhotosViewModel {
        return PhotosViewModel(photosInteractor: interactors.photos)
    }

    func makePhotoDetailViewModel(photo: Photo) -> PhotoDetailViewModel {
        return PhotoDetailViewModel(photo: photo)
    }

    func makeImageViewModel(url: URL) -> ImageViewModel {
        return ImageViewModel(imageURL: url, interactor: interactors.images)
    }

    func makeTopicsViewModel() -> TopicsViewModel {
        return TopicsViewModel(topicsInteractor: interactors.topics)
    }

    func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel {
        return TopicRowViewModel(topic: topic, topicsInteractor: interactors.topics)
    }

    func makeSearchViewModel() -> SearchViewModel {
        return SearchViewModel(searchInteractor: interactors.search, appState: appState)
    }
}
