//
//  ApiClient.swift
//  AlamofireSample
//
//  Alamofire 5.12 networking client (SwiftUI / async-await).
//
//  Replaces the old URLSession-based `APIRepositoryProtocol.call(endpoint:)`.
//  Repositories now build an Alamofire `URLRequestConvertible` endpoint and
//  hand it to `ApiClient.request(_:)`, which validates + decodes it.
//
//  Auth is intentionally NOT baked into the shared client: this app talks to
//  Unsplash using a `Client-ID` header set per endpoint. `AuthenticationInterceptor`
//  would throw `.missingCredential` on every request when no OAuth token exists,
//  so OAuth is opt-in via `ApiClient.oauth(baseURL:)` instead.
//

import Foundation
import Alamofire

nonisolated final class ApiClient: Sendable {

    /// Shared, unauthenticated client. Endpoints attach their own auth headers.
    static let shared = ApiClient()

    let session: Session

    init(interceptor: (any RequestInterceptor)? = nil,
         configuration: URLSessionConfiguration = ApiClient.defaultConfiguration()) {
        session = Session(configuration: configuration, interceptor: interceptor)
    }

    static func defaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 5
        // Honor the shared URL cache so downloaded images are reused.
        configuration.urlCache = .shared
        return configuration
    }

    // MARK: - OAuth (opt-in)

    /// Builds a client whose requests are authenticated + auto-refreshed by
    /// `OAuthAuthenticator`. Only use this against a backend that issues OAuth
    /// tokens — see `OAuthHandler.swift`.
    static func oauth(baseURL: URL, store: OAuthCredentialStore = OAuthCredentialStore()) -> ApiClient {
        let authenticator = OAuthAuthenticator(baseURL: baseURL, store: store)
        let interceptor = AuthenticationInterceptor(authenticator: authenticator,
                                                     credential: store.credential)
        return ApiClient(interceptor: interceptor)
    }

    // MARK: - Requests

    /// Send a request and decode the JSON response into `T`.
    @discardableResult
    func request<T: Decodable>(_ convertible: URLRequestConvertible,
                               as type: T.Type = T.self,
                               decoder: JSONDecoder = JSONDecoder(),
                               httpCodes: HTTPCodes = .success) async throws -> T {
        let response = await session.request(convertible)
            .validate(statusCode: httpCodes)
            .serializingDecodable(T.self, decoder: decoder)
            .response

        switch response.result {
        case let .success(value):
            return value
        case let .failure(error):
            throw ApiClient.mapError(error, statusCode: response.response?.statusCode)
        }
    }

    /// Fetch raw bytes (e.g. an image) from a URL.
    func data(from url: URL) async throws -> Data {
        let response = await session.request(url)
            .validate()
            .serializingData()
            .response

        switch response.result {
        case let .success(data):
            return data
        case let .failure(error):
            throw ApiClient.mapError(error, statusCode: response.response?.statusCode)
        }
    }

    /// For endpoints that return no body.
    func requestVoid(_ convertible: URLRequestConvertible,
                     httpCodes: HTTPCodes = .success) async throws {
        let response = await session.request(convertible)
            .validate(statusCode: httpCodes)
            .serializingData(emptyResponseCodes: [200, 204, 205])
            .response

        if case let .failure(error) = response.result {
            throw ApiClient.mapError(error, statusCode: response.response?.statusCode)
        }
    }

    // MARK: - Error mapping

    /// Maps Alamofire's `AFError` onto the app's shared `APIError`. Explicit
    /// cancellation is surfaced as `CancellationError` so SwiftUI `.task`
    /// teardown isn't reported to the user as a failure.
    static func mapError(_ error: any Error, statusCode: Int?) -> any Error {
        if let afError = error.asAFError, afError.isExplicitlyCancelledError {
            return CancellationError()
        }
        if let code = statusCode, !HTTPCodes.success.contains(code) {
            return APIError.httpCode(code)
        }
        return APIError.unexpectedResponse
    }
}
