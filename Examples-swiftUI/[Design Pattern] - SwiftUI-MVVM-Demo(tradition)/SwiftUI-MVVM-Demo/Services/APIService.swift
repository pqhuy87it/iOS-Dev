import Foundation

final class APIService: APIServiceType {
    private let baseURL: URL
    
    init(baseURL: URL = URL(string: "https://api.github.com")!) {
        self.baseURL = baseURL
    }

    func response<Request: APIRequestType>(from request: Request) async throws -> Request.Response {
        guard let pathURL = URL(string: request.path, relativeTo: baseURL),
              var urlComponents = URLComponents(url: pathURL, resolvingAgainstBaseURL: true) else {
            throw APIServiceError.invalidURL
        }
        
        urlComponents.queryItems = request.queryItems
        guard let url = urlComponents.url else {
            throw APIServiceError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Sử dụng Swift Concurrency
        let (data, httpResponse) = try await URLSession.shared.data(for: urlRequest)
        
        guard let response = httpResponse as? HTTPURLResponse, 200..<300 ~= response.statusCode else {
            throw APIServiceError.responseError
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            return try decoder.decode(Request.Response.self, from: data)
        } catch {
            throw APIServiceError.parseError(error)
        }
    }
}
