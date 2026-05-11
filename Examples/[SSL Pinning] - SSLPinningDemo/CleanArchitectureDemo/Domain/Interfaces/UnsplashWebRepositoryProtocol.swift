import Foundation

// Declare the functions that the App needs to call
protocol UnsplashWebRepositoryProtocol: WebRepositoryProtocol {
    func fetchLatestPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo]
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic]
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo]
}