import Foundation

struct SearchInteractor: SearchInteractorProtocol {
    let searchRepository: SearchRepositoryProtocol

    func searchPhotos(query: String, page: Int = 1, perPage: Int = 10) async throws -> SearchResult {
        let dto = try await searchRepository.searchPhotos(query: query, page: page, perPage: perPage)
        return dto.toDomain()
    }

    func getSearchHistory() async throws -> [String] {
        let history = try await searchRepository.fetchSearchHistory()
        return history.map { $0.keyword }
    }

    func saveSearchKeyword(_ keyword: String) async throws {
        try await searchRepository.saveSearchKeyword(keyword)
    }
}
