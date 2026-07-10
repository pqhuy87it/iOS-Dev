import Foundation
import Combine

#if DEBUG
    @MainActor final class StubViewModelFactory: ViewModelFactory {
        private let stubPhotoInteractor = StubPhotosInteractor()
        private let stubImagesInteractor = StubImagesInteractor(shouldFail: false)
        private let stubTopicsInteractor = StubTopicsInteractor()
        private let stubSearchInteractor = StubSearchInteractor()
        private let stubAppState = Store<AppState>(AppState())

        func makePhotosViewModel() -> PhotosViewModel {
            return PhotosViewModel(photosInteractor: stubPhotoInteractor)
        }

        func makePhotoDetailViewModel(photo: Photo) -> PhotoDetailViewModel {
            return PhotoDetailViewModel(photo: photo)
        }

        func makeImageViewModel(url: URL) -> ImageViewModel {
            return ImageViewModel(imageURL: url, interactor: stubImagesInteractor)
        }

        func makeTopicsViewModel() -> TopicsViewModel {
            return TopicsViewModel(topicsInteractor: stubTopicsInteractor)
        }

        func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel {
            return TopicRowViewModel(topic: topic, topicsInteractor: stubTopicsInteractor)
        }

        func makeSearchViewModel() -> SearchViewModel {
            return SearchViewModel(searchInteractor: stubSearchInteractor, appState: stubAppState)
        }
    }
#endif
