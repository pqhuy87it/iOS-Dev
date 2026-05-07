import Foundation

struct PhotoInteractor: PhotoInteractorProtocol {
    // 2. Phụ thuộc vào Protocol (UnsplashWebRepository) thay vì UnsplashWebRepository
    let webRepository: UnsplashWebRepositoryProtocol
    let dbRepository: SearchDBRepositoryProtocol
    
    // Gán giá trị mặc định cho page và perPage để lúc gọi cho gọn
    func fetchPhotos(page: Int = 1, perPage: Int = 10) async throws -> [ApiModel.Photo] {
        // 3. Thêm 'try await' và page nên bắt đầu từ 1
        let photos = try await webRepository.fetchLatestPhotos(page: page, perPage: perPage)
        return photos
    }
    
    func searchPhotos(query: String, page: Int = 1, perPage: Int = 10) async throws -> ApiModel.SearchResult {
        let result = try await webRepository.searchPhotos(query: query, page: page, perPage: perPage)
        return result
    }
    
    func fetchTopics(page: Int = 1, perPage: Int = 10) async throws -> [ApiModel.Topic] {
        return try await webRepository.fetchTopics(page: page, perPage: perPage)
    }
    
    func fetchTopicPhotos(slug: String, page: Int = 1, perPage: Int = 30) async throws -> [ApiModel.Photo] {
        // Gọi thẳng xuống WebRepository
        return try await webRepository.fetchTopicPhotos(slug: slug, page: page, perPage: perPage)
    }
    
    func getSearchHistory() async throws -> [String] {
        let history = try await dbRepository.fetchSearchHistory()
        return history.map { $0.keyword }
    }
    
    func saveSearchKeyword(_ keyword: String) async throws {
        try await dbRepository.saveSearchKeyword(keyword)
    }
}
