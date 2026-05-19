import Foundation
import SwiftUI

// ╔══════════════════════════════════════════════════════════╗
// ║  A3. VIEWMODEL — ASYNC/AWAIT                              ║
// ╚══════════════════════════════════════════════════════════╝

@Observable
final class AsyncPostListVM {
    private(set) var posts: [Post] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: APIError?
    private(set) var currentPage = 1
    private(set) var hasMore = true
    
    private let service: AsyncPostServiceProtocol
    
    init(service: AsyncPostServiceProtocol = AsyncPostService()) {
        self.service = service
    }
    
    // === Load initial page ===
    @MainActor
    func loadPosts() async {
        isLoading = true
        error = nil
        currentPage = 1
        
        do {
            let result = try await service.getPosts(page: 1)
            posts = result
            hasMore = !result.isEmpty
            isLoading = false
        } catch let err as APIError {
            error = err
            isLoading = false
        } catch {
            self.error = .networkError(error)
            isLoading = false
        }
    }
    
    // === Load next page (pagination) ===
    @MainActor
    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        
        do {
            let nextPage = currentPage + 1
            let newPosts = try await service.getPosts(page: nextPage)
            posts.append(contentsOf: newPosts)
            currentPage = nextPage
            hasMore = !newPosts.isEmpty
        } catch { /* Silently fail for pagination */ }
        
        isLoadingMore = false
    }
    
    // === Create post ===
    @MainActor
    func createPost(title: String, body: String) async throws -> Post {
        let request = CreatePostRequest(title: title, body: body, userId: 1)
        let newPost = try await service.createPost(request)
        posts.insert(newPost, at: 0)
        return newPost
    }
    
    // === Delete post ===
    @MainActor
    func deletePost(id: Int) async throws {
        try await service.deletePost(id: id)
        posts.removeAll { $0.id == id }
    }
    
    // === Parallel fetch: posts + user info ===
    @MainActor
    func loadDashboard(userId: Int) async {
        isLoading = true
        
        async let postsTask = service.getPosts(page: 1)
        async let userPostsTask = service.getUserPosts(userId: userId)
        
        do {
            let (allPosts, _) = try await (postsTask, userPostsTask)
            posts = allPosts
        } catch let err as APIError {
            error = err
        } catch {
            self.error = .networkError(error)
        }
        
        isLoading = false
    }
    
    // === Retry logic ===
    @MainActor
    func loadWithRetry(maxRetries: Int = 3) async {
        isLoading = true
        error = nil
        
        for attempt in 1...maxRetries {
            do {
                posts = try await service.getPosts(page: 1)
                isLoading = false
                return // Thành công → thoát
            } catch let err as APIError where err.isRetryable && attempt < maxRetries {
                // Exponential backoff
                let delay = Double(attempt) * 1.5
                try? await Task.sleep(for: .seconds(delay))
                continue // Retry
            } catch let err as APIError {
                error = err
                break // Không retryable → dừng
            } catch {
                self.error = .networkError(error)
                break
            }
        }
        
        isLoading = false
    }
}
