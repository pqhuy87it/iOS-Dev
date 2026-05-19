import Foundation

public protocol NetworkTarget {
    var baseURL: URL { get }
    var path: String { get }
    var methodType: MethodType { get }
    var workType: WorkType { get }
    var providerType: AuthProviderType { get }
    var contentType: ContentType? { get }
    var headers: [String: String]? { get }
}

public extension NetworkTarget {
    var pathAppendedURL: URL {
        var url = baseURL
        url.appendPathComponent(path)
        return url
    }
}
