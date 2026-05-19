import Foundation

final class AsyncPostService: AsyncPostServiceProtocol {
    private let client: AsyncAPIClientProtocol
    
    init(client: AsyncAPIClientProtocol = AsyncAPIClient()) {
        self.client = client
    }
    
    func getPosts(page: Int) async throws -> [Post] {
        try await client.request(Endpoints.posts(page: page))
    }
    
    func getPost(id: Int) async throws -> Post {
        try await client.request(Endpoints.post(id: id))
    }
    
    func createPost(_ request: CreatePostRequest) async throws -> Post {
        try await client.request(Endpoints.createPost(request))
    }
    
    func updatePost(id: Int, _ request: CreatePostRequest) async throws -> Post {
        try await client.request(Endpoints.updatePost(id: id, request))
    }
    
    func deletePost(id: Int) async throws {
        _ = try await client.requestRaw(Endpoints.deletePost(id: id))
    }
    
    func getUserPosts(userId: Int) async throws -> [Post] {
        try await client.request(Endpoints.userPosts(userId: userId))
    }
}
