import Foundation

final class AsyncAPIClient: AsyncAPIClientProtocol {
    private let session: URLSession
    private let baseURL: String
    private let tokenProvider: (() async -> String?)?
    private let decoder: JSONDecoder
    
    init(
        baseURL: String = Endpoints.baseURL,
        session: URLSession = .shared,
        tokenProvider: (() async -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await requestRaw(endpoint)
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    func requestRaw(_ endpoint: Endpoint) async throws -> Data {
        // 1. Build URL
        guard var components = URLComponents(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        components.queryItems = endpoint.queryItems
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        // 2. Build Request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // Inject auth token
        if let token = await tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Custom headers
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 3. Execute
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as URLError where error.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(error)
        }
        
        // 4. Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
    }
}
