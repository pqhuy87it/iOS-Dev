import Foundation

// === API Errors ===

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case notFound
    case serverError
    case timeout
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL không hợp lệ"
        case .invalidResponse: return "Response không hợp lệ"
        case .httpError(let code, _): return "HTTP Error: \(code)"
        case .decodingError: return "Không thể parse dữ liệu"
        case .networkError(let err): return "Lỗi mạng: \(err.localizedDescription)"
        case .unauthorized: return "Phiên đăng nhập hết hạn"
        case .notFound: return "Không tìm thấy dữ liệu"
        case .serverError: return "Lỗi máy chủ"
        case .timeout: return "Quá thời gian chờ"
        case .cancelled: return "Đã huỷ request"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError, .timeout: return true
        default: return false
        }
    }
}
