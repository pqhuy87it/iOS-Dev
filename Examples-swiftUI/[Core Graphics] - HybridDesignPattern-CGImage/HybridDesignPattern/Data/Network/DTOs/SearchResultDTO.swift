import Foundation

struct SearchResultDTO: Codable {
    let total: Int
    let totalPages: Int
    let results: [PhotoDTO]

    enum CodingKeys: String, CodingKey {
        case total, results
        case totalPages = "total_pages"
    }
}

// MARK: - Mapping Extension

extension SearchResultDTO {
    func toDomain() -> SearchResult {
        return SearchResult(total: total,
                            totalPages: totalPages,
                            results: results.map { $0.toDomain() })
    }
}
