import Foundation

struct CreatePostRequest: Codable {
    let title: String
    let body: String
    let userId: Int
}
