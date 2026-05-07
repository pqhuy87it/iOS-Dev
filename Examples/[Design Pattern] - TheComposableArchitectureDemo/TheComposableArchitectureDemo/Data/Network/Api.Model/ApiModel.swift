import Foundation

// Namespace to contain models mapping from API responses
enum ApiModel { }

extension ApiModel {
    // 3. Add Hashable to User
    struct User: Codable, Hashable {
        let id: String
        let username: String
        let name: String
    }
    
    // SearchResult is not used to navigate directly so it does not strictly need Hashable
    struct SearchResult: Codable {
        let total: Int
        let totalPages: Int
        let results: [Photo]
        
        enum CodingKeys: String, CodingKey {
            case total, results
            case totalPages = "total_pages"
        }
    }
}

extension ApiModel {
    // 1. Add Hashable to Photo
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
    
    // 2. Add Hashable to PhotoUrls
    struct PhotoUrls: Codable, Hashable {
        let raw: URL
        let full: URL
        let regular: URL
        let small: URL
        let thumb: URL
    }
}

extension ApiModel {
    struct Topic: Codable, Identifiable, Hashable {
        let id: String
        let slug: String
        let title: String
        let description: String?
        // Unsplash returns the cover photo of the topic, reuse the Photo model
        let coverPhoto: Photo?
        
        enum CodingKeys: String, CodingKey {
            case id, slug, title, description
            case coverPhoto = "cover_photo" // Map snake_case sang camelCase
        }
    }
}
