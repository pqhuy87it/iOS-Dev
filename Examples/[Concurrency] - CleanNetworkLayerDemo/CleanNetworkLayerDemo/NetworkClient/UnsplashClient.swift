import Foundation

public struct UnsplashClient: Sendable {
    private let accessKey: String
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(
        accessKey: String = "fmj4VAsTTwc0QgRQRiPb_9ok4n-I9hfPTk1EPLyu5Q8",
        baseURL: String = "https://api.unsplash.com",
        session: URLSession = .shared
    ) {
        self.accessKey = accessKey
        self.baseURL = URL(string: baseURL)!
        self.session = session
        
        let decoder = JSONDecoder()
        // Bạn có thể setup date format hoặc key decoding strategy ở đây nếu cần
        self.decoder = decoder
    }
    
    public func request<T: Decodable>(endpoint: Endpoint) async throws -> T {
        // 1. Dựng URL an toàn với URLComponents
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        components.queryItems = endpoint.queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        // 2. Tạo Request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        // 3. Gắn Header tự động (Định tuyến Auth nằm tập trung ở đây)
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        // 4. Encode Body (Nếu là method POST/PUT)
        if let body = endpoint.body {
            request.httpBody = try? JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // 5. Gọi API
        let (data, response) = try await session.data(for: request)
        
        // 6. Xử lý lỗi HTTP
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpCode(httpResponse.statusCode)
        }
        
        // 7. Decode
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)") // Log lỗi để debug
            throw APIError.unexpectedResponse
        }
    }
}
