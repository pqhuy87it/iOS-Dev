import Foundation

// Thực thi Repository
struct UnsplashWebRepository: UnsplashWebRepositoryProtocol {
    
    private let client: UnsplashClient
    
    // Inject Client qua init để dễ mock khi viết Unit Test
    init(client: UnsplashClient = UnsplashClient()) {
        self.client = client
    }
    
    func fetchLatestPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        return try await client.request(endpoint: UnsplashEndpoint.latestPhotos(page: page, perPage: perPage))
    }
    
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult {
        return try await client.request(endpoint: UnsplashEndpoint.searchPhotos(query: query, page: page, perPage: perPage))
    }
    
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic] {
        return try await client.request(endpoint: UnsplashEndpoint.topics(page: page, perPage: perPage))
    }
    
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        return try await client.request(endpoint: UnsplashEndpoint.topicPhotos(slug: slug, page: page, perPage: perPage))
    }
}
