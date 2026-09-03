import Foundation
import Alamofire

struct TopicsRepository: TopicsRepositoryProtocol {
    let apiClient: ApiClient

    // API key from Secrets.plist
    let clientId: String = AppConfig.unsplashClientID

    init(apiClient: ApiClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTopics(page: Int, perPage: Int) async throws -> [TopicDTO] {
        try await apiClient.request(
            API.topics(page: page, perPage: perPage, clientId: clientId)
        )
    }

    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [PhotoDTO] {
        try await apiClient.request(
            API.topicPhotos(slug: slug, page: page, perPage: perPage, clientId: clientId)
        )
    }
}

// MARK: - Configure Endpoints for Unsplash
extension TopicsRepository {
    enum API {
        case topics(page: Int, perPage: Int, clientId: String)
        case topicPhotos(slug: String, page: Int, perPage: Int, clientId: String)
    }
}

extension TopicsRepository.API: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .topics(page, perPage, clientId):
            return try Unsplash.makeRequest(
                path: "/topics?page=\(page)&per_page=\(perPage)",
                clientId: clientId
            )
        case let .topicPhotos(slug, page, perPage, clientId):
            return try Unsplash.makeRequest(
                path: "/topics/\(slug)/photos?page=\(page)&per_page=\(perPage)",
                clientId: clientId
            )
        }
    }
}

// MARK: - Stub (For Xcode Previews & Unit Tests)
struct StubTopicsInteractor: TopicsInteractorProtocol {
    func fetchTopics(page: Int, perPage: Int) async throws -> [Topic] {
        return []
    }

    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [Photo] {
        return []
    }
}
