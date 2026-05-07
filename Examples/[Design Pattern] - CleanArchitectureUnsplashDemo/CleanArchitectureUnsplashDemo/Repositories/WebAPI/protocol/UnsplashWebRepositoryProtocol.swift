import Foundation

// Khai báo các chức năng mà App cần gọi
protocol UnsplashWebRepositoryProtocol: WebRepositoryProtocol {
    func fetchLatestPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo]
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic]
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo]
}
