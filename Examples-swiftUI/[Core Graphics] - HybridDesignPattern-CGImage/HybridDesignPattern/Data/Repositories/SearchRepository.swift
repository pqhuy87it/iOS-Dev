import Foundation

// MARK: - Data implementation

struct SearchRepository: SearchRepositoryProtocol, APIRepositoryProtocol {
    let session: URLSession
    let baseURL: String = "https://api.unsplash.com"

    // API key from Secrets.plist
    let clientId: String = AppConfig.unsplashClientID

    private let dbRepository: MainDBRepository

    init(session: URLSession, dbRepository: MainDBRepository) {
        self.session = session
        self.dbRepository = dbRepository
    }

    // MARK: - Network
    
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResultDTO {
        try await call(
            endpoint: API.searchPhotos(query: query, page: page, perPage: perPage, clientId: clientId)
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

extension SearchRepository.API: APICall {
    var path: String {
        switch self {
        case let .searchPhotos(query, page, perPage, _):
            // Must encode characters with diacritics/spaces if the user searches for complex keywords
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "/search/photos?query=\(encodedQuery)&page=\(page)&per_page=\(perPage)"
        }
    }

    var method: String {
        return "GET"
    }

    var headers: [String: String]? {
        let clientId: String
        switch self {
        case let .searchPhotos(_, _, _, key):
            clientId = key
        }
        return [
            "Accept-Version": "v1",
            "Authorization": "Client-ID \(clientId)",
            "Accept": "application/json"
        ]
    }

    func body() throws -> Data? {
        return nil // GET method does not have a body
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
