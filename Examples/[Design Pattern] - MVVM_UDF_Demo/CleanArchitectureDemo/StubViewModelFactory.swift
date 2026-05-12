import Combine

#if DEBUG
    @MainActor final class StubViewModelFactory: ViewModelFactory {
        private let stubPhotoInteractor = StubPhotoInteractor()
        private let stubImagesInteractor = StubImagesInteractor(shouldFail: false)
        private let stubAppState = Store<AppState>(AppState())

        func makePhotosViewModel() -> PhotosViewModel {
            return PhotosViewModel(photoInteractor: stubPhotoInteractor)
        }

        func makeImageViewModel() -> ImageViewModel {
            return ImageViewModel(interactor: stubImagesInteractor)
        }

        func makeTopicsViewModel() -> TopicsViewModel {
            return TopicsViewModel(photoInteractor: stubPhotoInteractor)
        }

        func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel {
            return TopicRowViewModel(topic: topic, photoInteractor: stubPhotoInteractor)
        }

        func makeSearchViewModel() -> SearchViewModel {
            return SearchViewModel(photoInteractor: stubPhotoInteractor, appState: stubAppState)
        }
    }
#endif
