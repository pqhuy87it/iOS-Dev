import Foundation
import Alamofire

// MARK: - Data implementation

struct SearchRepository: SearchRepositoryProtocol {
    let apiClient: ApiClient

    // API key from Secrets.plist
    let clientId: String = AppConfig.unsplashClientID

    private let dbRepository: MainDBRepository

    init(apiClient: ApiClient = .shared, dbRepository: MainDBRepository) {
        self.apiClient = apiClient
        self.dbRepository = dbRepository
    }

    // MARK: - Network

    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResultDTO {
        try await apiClient.request(
            API.searchPhotos(query: query, page: page, perPage: perPage, clientId: clientId)
        )
    }

    // MARK: - Local DB (MainDBRepository)

    @MainActor func fetchSearchHistory() async throws -> [DBModel.SearchHistory] {
        try await dbRepository.fetchSearchHistory()
    }

    func saveSearchKeyword(_ keyword: String) async throws {
        try await dbRepository.saveSearchKeyword(keyword)
    }
}

// MARK: - Configure Endpoints for Unsplash

extension SearchRepository {
    enum API {
        case searchPhotos(query: String, page: Int, perPage: Int, clientId: String)
    }
}

extension SearchRepository.API: URLRequestConvertible {
    func asURLRequest() throws -> URLRequest {
        switch self {
        case let .searchPhotos(query, page, perPage, clientId):
            // Encode characters with diacritics/spaces for complex keywords.
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return try Unsplash.makeRequest(
                path: "/search/photos?query=\(encodedQuery)&page=\(page)&per_page=\(perPage)",
                clientId: clientId
            )
        }
    }
}

// MARK: - Stub (For Xcode Previews & Unit Tests)

struct StubSearchInteractor: SearchInteractorProtocol {
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResult {
        return SearchResult(total: 0, totalPages: 0, results: [])
    }

    func getSearchHistory() async throws -> [String] { return ["Cat", "Nature"] }
    func saveSearchKeyword(_ keyword: String) async throws {}
}
