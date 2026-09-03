import Foundation

struct PhotoDTO: Codable, Identifiable, Hashable {
    let id: String
    let width: Int
    let height: Int
    let color: String?
    let description: String?
    let altDescription: String?
    let urls: PhotoUrlsDTO
    let user: UserDTO

    enum CodingKeys: String, CodingKey {
        case id, width, height, color, description, urls, user
        case altDescription = "alt_description"
    }

    struct PhotoUrlsDTO: Codable, Hashable {
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
        let thumb: URL
    }
}

// MARK: - Mapping Extension

extension PhotoDTO {
    func toDomain() -> Photo {
        return Photo(id: id,
                     width: width,
                     height: height,
                     color: color,
                     description: description,
                     altDescription: altDescription,
                     urls: Photo.Urls(raw: urls.raw,
                                      full: urls.full,
                                      regular: urls.regular,
                                      small: urls.small,
                                      thumb: urls.thumb),
                     user: user.toDomain())
    }
}
