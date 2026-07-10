import Foundation

protocol TopicsRepositoryProtocol {
    func fetchTopics(page: Int, perPage: Int) async throws -> [TopicDTO]
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [PhotoDTO]
}
