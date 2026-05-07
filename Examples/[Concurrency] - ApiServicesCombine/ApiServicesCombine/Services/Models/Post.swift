import Foundation

struct Post: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let body: String
    let userId: Int
}
