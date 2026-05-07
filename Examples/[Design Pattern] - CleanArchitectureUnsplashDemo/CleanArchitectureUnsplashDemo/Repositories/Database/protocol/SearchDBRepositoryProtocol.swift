import SwiftData
import Foundation

protocol SearchDBRepositoryProtocol {
    @MainActor func fetchSearchHistory() async throws -> [DBModel.SearchHistory]
    func saveSearchKeyword(_ keyword: String) async throws
}
