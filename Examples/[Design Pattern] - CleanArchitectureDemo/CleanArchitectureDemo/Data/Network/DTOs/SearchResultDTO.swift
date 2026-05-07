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
