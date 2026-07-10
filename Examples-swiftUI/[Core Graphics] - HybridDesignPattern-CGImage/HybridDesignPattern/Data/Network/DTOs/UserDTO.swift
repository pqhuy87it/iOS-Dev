import Foundation

struct UserDTO: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let name: String?
    let firstName: String?
    let lastName: String?
    let instagramUsername: String?
    let twitterUsername: String?
    let portfolioUrl: URL?
    let totalCollections: Int
    let profileImage: ProfileImageDTO
    let links: LinksDTO

    enum CodingKeys: String, CodingKey {
        case id, username, name, links
        case firstName = "first_name"
        case lastName = "last_name"
        case instagramUsername = "instagram_username"
        case twitterUsername = "twitter_username"
        case portfolioUrl = "portfolio_url"
        case totalCollections = "total_collections"
        case profileImage = "profile_image"
    }

    struct ProfileImageDTO: Codable, Hashable {
        let small: URL
        let medium: URL
        let large: URL
    }

    struct LinksDTO: Codable, Hashable {
        let `self`: URL
        let html: URL
        let photos: URL
    }
}

// MARK: - Mapping Extension

extension UserDTO {
    func toDomain() -> User {
        return User(id: id,
                    username: username,
                    name: name,
                    firstName: firstName,
                    lastName: lastName,
                    instagramUsername: instagramUsername,
                    twitterUsername: twitterUsername,
                    portfolioUrl: portfolioUrl,
                    totalCollections: totalCollections,
                    profileImage: User.ProfileImage(small: profileImage.small,
                                                    medium: profileImage.medium,
                                                    large: profileImage.large))
    }
}
