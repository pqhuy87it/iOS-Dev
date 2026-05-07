import Foundation

protocol PhotoInteractorProtocol {
    func fetchPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo]
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic]
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo]
    
    // Thêm 2 hàm xử lý lịch sử
    func getSearchHistory() async throws -> [String]
    func saveSearchKeyword(_ keyword: String) async throws
}
