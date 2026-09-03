import Foundation

struct User: Identifiable, Hashable {
    let id: String
    let username: String
    let name: String?
    let firstName: String?
    let lastName: String?
    let instagramUsername: String?
    let twitterUsername: String?
    let portfolioUrl: URL?
    let totalCollections: Int
    let profileImage: ProfileImage

    struct ProfileImage: Hashable {
        let small: URL
        let medium: URL
        let large: URL
    }
}
