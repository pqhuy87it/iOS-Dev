import Foundation

extension ApiModel {
    // 1. Thêm Hashable vào Photo
    struct Photo: Codable, Identifiable, Hashable {
        let id: String
        let width: Int
        let height: Int
        let color: String?
        let description: String?
        let altDescription: String?
        let urls: PhotoUrls
        let user: User
        
        enum CodingKeys: String, CodingKey {
            case id, width, height, color, description, urls, user
            case altDescription = "alt_description"
        }
    }
    
    // 2. Thêm Hashable vào PhotoUrls
    struct PhotoUrls: Codable, Hashable {
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
        let thumb: URL
    }
}
