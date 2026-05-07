import Foundation

// ╔══════════════════════════════════════════════════════════╗
// ║  A2. SERVICE LAYER — ASYNC/AWAIT                          ║
// ╚══════════════════════════════════════════════════════════╝

protocol AsyncPostServiceProtocol: Sendable {
    func getPosts(page: Int) async throws -> [Post]
    func getPost(id: Int) async throws -> Post
    func createPost(_ request: CreatePostRequest) async throws -> Post
    func updatePost(id: Int, _ request: CreatePostRequest) async throws -> Post
    func deletePost(id: Int) async throws
    func getUserPosts(userId: Int) async throws -> [Post]
}

