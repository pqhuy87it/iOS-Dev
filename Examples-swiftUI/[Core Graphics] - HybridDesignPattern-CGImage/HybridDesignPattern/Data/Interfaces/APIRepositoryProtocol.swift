import Combine
import Foundation

protocol APIRepositoryProtocol {
    var session: URLSession { get }
    var baseURL: String { get }
}

extension APIRepositoryProtocol {
    func call<Value: Decodable, Decoder: TopLevelDecoder>(
        endpoint: APICall,
        decoder: Decoder = JSONDecoder(),
        httpCodes: HTTPCodes = 200 ..< 300 // .success
    ) async throws -> Value
        where Decoder.Input == Data
    {
        let request = try endpoint.urlRequest(baseURL: baseURL)
        let (data, response) = try await session.data(for: request)

        guard let code = (response as? HTTPURLResponse)?.statusCode else {
            throw APIError.unexpectedResponse
        }
        guard httpCodes.contains(code) else {
            throw APIError.httpCode(code)
        }

        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw APIError.unexpectedResponse
        }
    }
}
