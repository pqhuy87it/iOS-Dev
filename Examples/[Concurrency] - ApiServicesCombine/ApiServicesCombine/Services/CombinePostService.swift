import Foundation
import Combine

final class CombinePostService: CombinePostServiceProtocol {
    private let client: CombineAPIClientProtocol
    
    init(client: CombineAPIClientProtocol = CombineAPIClient()) {
        self.client = client
    }
    
    func getPosts(page: Int) -> AnyPublisher<[Post], APIError> {
        client.request(Endpoints.posts(page: page))
    }
    
    func getPost(id: Int) -> AnyPublisher<Post, APIError> {
        client.request(Endpoints.post(id: id))
    }
    
    func createPost(_ request: CreatePostRequest) -> AnyPublisher<Post, APIError> {
        client.request(Endpoints.createPost(request))
    }
    
    func deletePost(id: Int) -> AnyPublisher<Void, APIError> {
        client.requestRaw(Endpoints.deletePost(id: id))
            .map { _ in () }   // Data → Void
            .eraseToAnyPublisher()
    }
    
    func getUserPosts(userId: Int) -> AnyPublisher<[Post], APIError> {
        client.request(Endpoints.userPosts(userId: userId))
    }
}
