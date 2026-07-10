import SwiftData
import Foundation

protocol SearchRepositoryProtocol {
    // Network: fetch image
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResultDTO
    // Local DB: query history
    @MainActor func fetchSearchHistory() async throws -> [DBModel.SearchHistory]
    func saveSearchKeyword(_ keyword: String) async throws
}
