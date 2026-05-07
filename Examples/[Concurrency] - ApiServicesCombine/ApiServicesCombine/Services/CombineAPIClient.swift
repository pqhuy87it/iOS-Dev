import Foundation
import Combine

final class CombineAPIClient: CombineAPIClientProtocol {
    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder
    
    init(
        baseURL: String = Endpoints.baseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        
        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func request<T: Decodable>(_ endpoint: Endpoint) -> AnyPublisher<T, APIError> {
        requestRaw(endpoint)
            // Decode JSON → Model
            .decode(type: T.self, decoder: decoder)
            // Map decoding error → APIError
            .mapError { error in
                if let apiError = error as? APIError { return apiError }
                return .decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func requestRaw(_ endpoint: Endpoint) -> AnyPublisher<Data, APIError> {
        // 1. Build URL
        guard var components = URLComponents(string: baseURL + endpoint.path) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        components.queryItems = endpoint.queryItems
        
        guard let url = components.url else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        // 2. Build Request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        endpoint.headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 3. Execute → Publisher pipeline
        return session.dataTaskPublisher(for: request)
            // Map network errors
            .mapError { urlError -> APIError in
                switch urlError.code {
                case .timedOut: return .timeout
                case .cancelled: return .cancelled
                default: return .networkError(urlError)
                }
            }
            // Validate HTTP response
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }
                switch http.statusCode {
                case 200...299: return data
                case 401: throw APIError.unauthorized
                case 404: throw APIError.notFound
                case 500...599: throw APIError.serverError
                default: throw APIError.httpError(statusCode: http.statusCode, data: data)
                }
            }
            .mapError { ($0 as? APIError) ?? .networkError($0) }
            .eraseToAnyPublisher()
    }
}
