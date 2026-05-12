import Foundation
import SwiftUI

@MainActor protocol ViewModelFactory {
    func makePhotosViewModel() -> PhotosViewModel
    func makeImageViewModel() -> ImageViewModel
    func makeTopicsViewModel() -> TopicsViewModel
    func makeTopicRowViewModel(topic: Topic) -> TopicRowViewModel
    func makeSearchViewModel() -> SearchViewModel
}
