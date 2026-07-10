import Foundation

protocol SearchInteractorProtocol {
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResult
    func getSearchHistory() async throws -> [String]
    func saveSearchKeyword(_ keyword: String) async throws
}
