import Foundation

extension ApiModel {
    // 3. Thêm Hashable vào User
    struct User: Codable, Hashable {
        let id: String
        let username: String
        let name: String
    }
    
    // SearchResult không dùng để navigate trực tiếp nên không bắt buộc cần Hashable
    struct SearchResult: Codable {
        let total: Int
        let totalPages: Int
        let results: [Photo]
        
        enum CodingKeys: String, CodingKey {
            case total, results
            case totalPages = "total_pages"
        }
    }
}
