import Foundation

public enum UnsplashEndpoint: Endpoint {
    case latestPhotos(page: Int, perPage: Int)
    case searchPhotos(query: String, page: Int, perPage: Int)
    case topics(page: Int, perPage: Int)
    case topicPhotos(slug: String, page: Int, perPage: Int)
    
    public var path: String {
        switch self {
        case .latestPhotos:
            return "photos"
        case .searchPhotos:
            return "search/photos"
        case .topics:
            return "topics"
        case let .topicPhotos(slug, _, _):
            return "topics/\(slug)/photos"
        }
    }
    
    public var queryItems: [URLQueryItem]? {
        switch self {
        case let .latestPhotos(page, perPage),
             let .topics(page, perPage),
             let .topicPhotos(_, page, perPage):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
            
        case let .searchPhotos(query, page, perPage):
            return [
                URLQueryItem(name: "query", value: query), // Không cần tự addingPercentEncoding, URLComponents sẽ lo
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(perPage))
            ]
        }
    }
}
