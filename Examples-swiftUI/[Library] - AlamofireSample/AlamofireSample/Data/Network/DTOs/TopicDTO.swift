import Foundation

struct TopicDTO: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let title: String
    let description: String?
    let coverPhoto: PhotoDTO?

    enum CodingKeys: String, CodingKey {
        case id, slug, title, description
        case coverPhoto = "cover_photo"
    }
}

// MARK: - Mapping Extension

extension TopicDTO {
    func toDomain() -> Topic {
        return Topic(id: id,
                     slug: slug,
                     title: title,
                     description: description,
                     coverPhoto: coverPhoto?.toDomain())
    }
}
