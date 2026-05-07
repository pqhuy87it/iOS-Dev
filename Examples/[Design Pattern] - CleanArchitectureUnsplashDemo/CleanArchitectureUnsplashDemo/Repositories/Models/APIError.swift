import Foundation

// MARK: - Tiện ích hỗ trợ
enum APIError: Swift.Error, LocalizedError, Equatable {
    case invalidURL
    case httpCode(HTTPCode)
    case unexpectedResponse
    case imageDeserialization
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case let .httpCode(code): return "Unexpected HTTP code: \(code)"
        case .unexpectedResponse: return "Unexpected response from the server"
        case .imageDeserialization: return "Cannot deserialize image from Data"
        }
    }
}
