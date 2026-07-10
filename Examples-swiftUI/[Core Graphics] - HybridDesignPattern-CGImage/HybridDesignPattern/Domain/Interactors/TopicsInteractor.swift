import Foundation

struct TopicsInteractor: TopicsInteractorProtocol {
    private let topicsRepository: TopicsRepositoryProtocol

    init(topicsRepository: TopicsRepositoryProtocol) {
        self.topicsRepository = topicsRepository
    }

    func fetchTopics(page: Int = 1, perPage: Int = 10) async throws -> [Topic] {
        let dtos = try await topicsRepository.fetchTopics(page: page, perPage: perPage)
        return dtos.map { $0.toDomain() }
    }

    func fetchTopicPhotos(slug: String, page: Int = 1, perPage: Int = 30) async throws -> [Photo] {
        let dtos = try await topicsRepository.fetchTopicPhotos(slug: slug, page: page, perPage: perPage)
        return dtos.map { $0.toDomain() }
    }
}
