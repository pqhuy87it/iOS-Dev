import Foundation

struct Topic: Identifiable, Hashable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    let coverPhoto: Photo?
}
