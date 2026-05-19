import Foundation

enum APIServiceError: Error, LocalizedError {
    case invalidURL
    case responseError
    case parseError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .responseError: return "Network error"
        case .parseError(let error): return "Parse error: \(error.localizedDescription)"
        }
    }
}
