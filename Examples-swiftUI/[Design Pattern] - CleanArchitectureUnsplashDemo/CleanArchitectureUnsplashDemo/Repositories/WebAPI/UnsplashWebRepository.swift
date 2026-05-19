import Foundation

// Thực thi Repository
struct UnsplashWebRepository: UnsplashWebRepositoryProtocol {
    let session: URLSession
    let baseURL: String = "https://api.unsplash.com"
    
    // Đăng ký tài khoản dev trên Unsplash để lấy API Key này
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

// MARK: - Cấu hình Endpoints cho Unsplash
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
            // Gắn query parameters trực tiếp vào đường dẫn
            return "/photos?page=\(page)&per_page=\(perPage)"
        case let .searchPhotos(query, page, perPage, _):
            // Phải encode ký tự có dấu/dấu cách nếu người dùng search từ khoá phức tạp
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "/search/photos?query=\(encodedQuery)&page=\(page)&per_page=\(perPage)"
        case let .topics(page, perPage, _):
            // Thêm path cho topics
            return "/topics?page=\(page)&per_page=\(perPage)"
        case let .topicPhotos(slug, page, perPage, _):
            // Ghép slug vào đường dẫn đúng như cấu trúc bạn vừa thấy
            return "/topics/\(slug)/photos?page=\(page)&per_page=\(perPage)"
            
        }
    }
    
    var method: String {
        return "GET"
    }
    
    var headers: [String: String]? {
        // Tách API key để inject vào header
        let clientId: String
        switch self {
        case let .latestPhotos(_, _, key),
            let .searchPhotos(_, _, _, key),
            let .topics(_, _, key),
            let .topicPhotos(_, _, _, key):
            clientId = key
        }
        
        // Unsplash yêu cầu Accept-Version và Authorization header
        return [
            "Accept-Version": "v1",
            "Authorization": "Client-ID \(clientId)",
            "Accept": "application/json"
        ]
    }
    
    func body() throws -> Data? {
        return nil // Method GET không có body
    }
}

// MARK: - Stub (Dành cho Xcode Previews & Unit Tests)
// Giống như StubCountriesInteractor trong dự án mẫu của bạn
struct StubPhotoInteractor: PhotoInteractorProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        // Trả về một mảng rỗng hoặc Mock data để Preview hiển thị ngay lập tức
        return []
    }
    
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult {
        return ApiModel.SearchResult(total: 0, totalPages: 0, results: [])
    }
    
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic] {
        return []
    }
    
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        return []
    }
    
    func getSearchHistory() async throws -> [String] { return ["Mèo", "Thiên nhiên"] }
    func saveSearchKeyword(_ keyword: String) async throws {}
}
