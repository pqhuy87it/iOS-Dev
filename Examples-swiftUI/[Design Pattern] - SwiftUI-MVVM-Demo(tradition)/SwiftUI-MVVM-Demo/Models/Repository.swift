import Foundation

struct Repository: Decodable, Hashable, Identifiable {
    let id: Int64
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let owner: User
}
