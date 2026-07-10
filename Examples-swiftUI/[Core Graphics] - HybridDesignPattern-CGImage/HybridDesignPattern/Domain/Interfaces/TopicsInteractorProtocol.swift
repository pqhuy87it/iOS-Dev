import Foundation

protocol TopicsInteractorProtocol {
    func fetchTopics(page: Int, perPage: Int) async throws -> [Topic]
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [Photo]
}
