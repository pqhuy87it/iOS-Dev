import Foundation

extension ApiModel {
    struct Topic: Codable, Identifiable, Hashable {
        let id: String
        let slug: String
        let title: String
        let description: String?
        // Unsplash trả về ảnh bìa của chủ đề, tái sử dụng luôn model Photo
        let coverPhoto: Photo?
        
        enum CodingKeys: String, CodingKey {
            case id, slug, title, description
            case coverPhoto = "cover_photo" // Map snake_case sang camelCase
        }
    }
}
