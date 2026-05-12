#if DEBUG
    @MainActor final class StubViewModelFactory: ViewModelFactory {
        private let stubPhotoInteractor = StubPhotoInteractor()
        private let stubImagesInteractor = StubImagesInteractor(shouldFail: false)
        
        func makePhotosViewModel() -> PhotosViewModel {
            // Truyền StubPhotoInteractor vào
            return PhotosViewModel(photoInteractor: stubPhotoInteractor)
        }

        func makeImageViewModel() -> ImageViewModel {
            // Truyền StubImagesInteractor vào
            return ImageViewModel(interactor: stubImagesInteractor)
        }

        // MARK: - Topics Module

        func makeTopicsViewModel() -> TopicsViewModel {
            return TopicsViewModel(photoInteractor: stubPhotoInteractor)
        }

        func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel {
            return TopicRowViewModel(topic: topic, photoInteractor: stubPhotoInteractor)
        }
        
        func makeSearchViewModel() -> SearchViewModel {
            return SearchViewModel(photoInteractor: stubPhotoInteractor)
        }
    }
#endif
