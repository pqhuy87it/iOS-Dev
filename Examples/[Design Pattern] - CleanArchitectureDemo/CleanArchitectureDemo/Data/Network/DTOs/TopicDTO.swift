import Foundation

struct TopicDTO: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    // Unsplash returns the cover photo of the topic, reuse the Photo model
    let coverPhoto: PhotoDTO?
    
    enum CodingKeys: String, CodingKey {
        case id, slug, title, description
        case coverPhoto = "cover_photo" // Map snake_case sang camelCase
    }
}
