import Foundation

struct Photo: Identifiable, Hashable {
    let id: String
    let width: Int
    let height: Int
    let color: String?
    let description: String?
    let altDescription: String?
    let urls: Urls
    let user: User
    
    struct Urls: Hashable {
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
        let thumb: URL
    }
}
