import Foundation
import Combine

// Core Protocol for all Web Repositories
protocol WebRepositoryProtocol {
    var session: URLSession { get }
    var baseURL: String { get }
}

extension WebRepositoryProtocol {
    func call<Value, Decoder>(
        endpoint: APICall,
        decoder: Decoder = JSONDecoder(),
        httpCodes: HTTPCodes = 200 ..< 300
    ) async throws -> Value
    where Value: Decodable, Decoder: TopLevelDecoder, Decoder.Input == Data {

        let request = try endpoint.urlRequest(baseURL: baseURL)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            let sslCodes: Set<URLError.Code> = [
                .serverCertificateUntrusted,
                .serverCertificateHasBadDate,
                .serverCertificateNotYetValid,
                .serverCertificateHasUnknownRoot,
                .clientCertificateRejected
            ]
            if sslCodes.contains(urlError.code) {
                throw APIError.sslPinningFailed
            }
            throw urlError
        }

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