import UIKit
import Foundation

public struct ImageClient: Sendable {
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func downloadImage(from url: URL) async throws -> UIImage {
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        
        // 1. Kiểm tra HTTP Status Code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpCode(httpResponse.statusCode)
        }
        
        // 2. Parse Data thành UIImage
        guard let image = UIImage(data: data) else {
            throw APIError.imageDeserialization
        }
        
        return image
    }
}
