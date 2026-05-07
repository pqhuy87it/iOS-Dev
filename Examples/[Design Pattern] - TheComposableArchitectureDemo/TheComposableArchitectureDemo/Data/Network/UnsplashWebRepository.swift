import Foundation

// Implement Repository
struct UnsplashWebRepository: UnsplashWebRepositoryProtocol {
    let session: URLSession
    let baseURL: String = "https://api.unsplash.com"
    
    // Register a dev account on Unsplash to get this API Key
    let clientId: String = "fmj4VAsTTwc0QgRQRiPb_9ok4n-I9hfPTk1EPLyu5Q8"
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchLatestPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        return try await call(
            endpoint: API.latestPhotos(page: page, perPage: perPage, clientId: clientId)
        )
    }
    
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult {
        return try await call(
            endpoint: API.searchPhotos(query: query, page: page, perPage: perPage, clientId: clientId)
        )
    }
    
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic] {
        return try await call(
            endpoint: API.topics(page: page, perPage: perPage, clientId: clientId)
        )
    }
    
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        return try await call(
            endpoint: API.topicPhotos(slug: slug, page: page, perPage: perPage, clientId: clientId)
        )
    }
}

// MARK: - Configure Endpoints for Unsplash
extension UnsplashWebRepository {
    enum API {
        case latestPhotos(page: Int, perPage: Int, clientId: String)
        case searchPhotos(query: String, page: Int, perPage: Int, clientId: String)
        case topics(page: Int, perPage: Int, clientId: String)
        case topicPhotos(slug: String, page: Int, perPage: Int, clientId: String)
    }
}

extension UnsplashWebRepository.API: APICall {
    var path: String {
        switch self {
        case let .latestPhotos(page, perPage, _):
            // Attach query parameters directly to the path
            return "/photos?page=\(page)&per_page=\(perPage)"
        case let .searchPhotos(query, page, perPage, _):
            // Must encode characters with diacritics/spaces if the user searches for complex keywords
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "/search/photos?query=\(encodedQuery)&page=\(page)&per_page=\(perPage)"
        case let .topics(page, perPage, _):
            // Add path for topics
            return "/topics?page=\(page)&per_page=\(perPage)"
        case let .topicPhotos(slug, page, perPage, _):
            // Append slug to the path exactly like the structure you just saw
            return "/topics/\(slug)/photos?page=\(page)&per_page=\(perPage)"
            
        }
    }
    
    var method: String {
        return "GET"
    }
    
    var headers: [String: String]? {
        // Extract API key to inject into header
        let clientId: String
        switch self {
        case let .latestPhotos(_, _, key),
            let .searchPhotos(_, _, _, key),
            let .topics(_, _, key),
            let .topicPhotos(_, _, _, key):
            clientId = key
        }
        
        // Unsplash requires Accept-Version and Authorization headers
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
// Similar to StubCountriesInteractor in your sample project
struct StubPhotoInteractor: PhotoInteractorProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [Photo] {
        // Return an empty array or Mock data for Preview to display immediately
        return []
    }
    
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResult {
        return SearchResult(total: 0, totalPages: 0, results: [])
    }
    
    func fetchTopics(page: Int, perPage: Int) async throws -> [Topic] {
        return []
    }
    
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [Photo] {
        return []
    }
    
    func getSearchHistory() async throws -> [String] { return ["Cat", "Nature"] }
    func saveSearchKeyword(_ keyword: String) async throws {}
}