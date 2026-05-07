import Foundation

struct PaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let page: Int
    let totalPages: Int
    let total: Int
}
