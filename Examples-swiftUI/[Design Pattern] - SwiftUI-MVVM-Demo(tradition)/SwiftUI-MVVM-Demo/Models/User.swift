import Foundation

struct User: Decodable, Hashable, Identifiable {
    let id: Int64
    let login: String
    let avatarUrl: URL
}
