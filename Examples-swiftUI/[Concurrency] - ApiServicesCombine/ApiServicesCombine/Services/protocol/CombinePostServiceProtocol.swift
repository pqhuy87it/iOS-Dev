import Foundation
import Combine

protocol CombinePostServiceProtocol {
    func getPosts(page: Int) -> AnyPublisher<[Post], APIError>
    func getPost(id: Int) -> AnyPublisher<Post, APIError>
    func createPost(_ request: CreatePostRequest) -> AnyPublisher<Post, APIError>
    func deletePost(id: Int) -> AnyPublisher<Void, APIError>
    func getUserPosts(userId: Int) -> AnyPublisher<[Post], APIError>
}
