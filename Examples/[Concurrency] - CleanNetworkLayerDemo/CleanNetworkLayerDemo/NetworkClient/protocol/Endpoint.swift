import Foundation

// Định nghĩa HTTP Methods
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// Khung chuẩn cho mọi API Endpoint
public protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Encodable? { get }
}

// Cung cấp giá trị mặc định để các API GET không cần khai báo body
public extension Endpoint {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem]? { nil }
    var body: Encodable? { nil }
}
