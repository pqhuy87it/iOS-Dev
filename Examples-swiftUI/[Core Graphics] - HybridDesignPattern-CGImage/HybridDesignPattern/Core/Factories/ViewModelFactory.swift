import Foundation
import SwiftUI

@MainActor protocol ViewModelFactory {
    func makePhotosViewModel() -> PhotosViewModel
    func makePhotoDetailViewModel(photo: Photo) -> PhotoDetailViewModel
    func makeImageViewModel(url: URL) -> ImageViewModel
    func makeTopicsViewModel() -> TopicsViewModel
    func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel
    func makeSearchViewModel() -> SearchViewModel
}
