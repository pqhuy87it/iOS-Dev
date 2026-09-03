//
//  OAuthHandler.swift
//  AlamofireSample
//
//  Modernized for Alamofire 5.12 (SwiftUI).
//
//  Alamofire 4's `RequestAdapter` + `RequestRetrier` + the manual
//  "refresh token then replay pending requests" dance is now handled by
//  Alamofire's built-in `AuthenticationInterceptor`. We only implement the
//  `Authenticator` protocol (how to attach / refresh / detect-expiry a token)
//  and Alamofire does the locking, queuing and retrying for us.
//

import Foundation
import Alamofire

// MARK: - Credential

/// The set of tokens we hold for the user. `AuthenticationInterceptor` stores
/// this in memory and hands it back to us on every `apply` / `refresh` call.
nonisolated struct OAuthCredential: AuthenticationCredential, Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    /// Absolute time the access token stops being valid.
    let expiration: Date

    /// Alamofire refreshes *proactively* whenever this is `true` (before firing
    /// the request), so we add a small safety buffer instead of waiting for a 401.
    var requiresRefresh: Bool {
        Date(timeIntervalSinceNow: 60 * 5) > expiration
    }
}

// MARK: - Token persistence

/// Persists the credential across launches. Replaces the four separate
/// `UserDefaults` string keys from the old `OAuthHandler`.
///
/// For production, back this with the Keychain — the surface (`credential`
/// get/set) stays identical.
nonisolated final class OAuthCredentialStore: @unchecked Sendable {
    private let key = "oauth.credential"
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var credential: OAuthCredential? {
        get {
            lock.lock(); defer { lock.unlock() }
            guard let data = defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(OAuthCredential.self, from: data)
        }
        set {
            lock.lock(); defer { lock.unlock() }
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }

    func clear() { credential = nil }
}

// MARK: - Refresh endpoint response

nonisolated private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Authenticator

/// Implements the four questions Alamofire asks to manage an OAuth session:
/// how to *attach* a token, how to *refresh* it, whether a response *failed on
/// auth*, and whether a request *carried* a given token.
nonisolated final class OAuthAuthenticator: Authenticator, @unchecked Sendable {
    typealias Credential = OAuthCredential

    private let baseURL: URL
    private let store: OAuthCredentialStore
    /// A bare session (no interceptor) used only to hit the token endpoint,
    /// so refreshing can never recurse into itself.
    private let refreshSession: Session

    init(baseURL: URL, store: OAuthCredentialStore) {
        self.baseURL = baseURL
        self.store = store
        self.refreshSession = Session()
    }

    /// Attach the bearer token — but only to requests aimed at our own API.
    func apply(_ credential: OAuthCredential, to urlRequest: inout URLRequest) {
        guard let url = urlRequest.url,
              url.absoluteString.hasPrefix(baseURL.absoluteString) else { return }
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }

    /// Exchange the refresh token for a new credential.
    func refresh(_ credential: OAuthCredential,
                 for session: Session,
                 completion: @escaping @Sendable (Result<OAuthCredential, any Error>) -> Void) {
        let endpoint = baseURL.appendingPathComponent("oauth2/token")
        let parameters: Parameters = [
            "grant_type": "refresh_token",
            "refresh_token": credential.refreshToken,
        ]

        refreshSession.request(endpoint,
                               method: .post,
                               parameters: parameters,
                               encoding: JSONEncoding.default)
            .validate()
            .responseDecodable(of: TokenResponse.self) { [store] response in
                switch response.result {
                case let .success(token):
                    let newCredential = OAuthCredential(
                        accessToken: token.accessToken,
                        refreshToken: token.refreshToken,
                        tokenType: token.tokenType ?? "Bearer",
                        expiration: Date(timeIntervalSinceNow: token.expiresIn ?? 3600)
                    )
                    store.credential = newCredential
                    completion(.success(newCredential))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
    }

    /// A 401 means the token was rejected → trigger a refresh + retry.
    func didRequest(_ urlRequest: URLRequest,
                    with response: HTTPURLResponse,
                    failDueToAuthenticationError error: any Error) -> Bool {
        response.statusCode == 401
    }

    /// Confirms the request actually carried this credential (so Alamofire
    /// doesn't refresh for an unrelated failure).
    func isRequest(_ urlRequest: URLRequest,
                   authenticatedWith credential: OAuthCredential) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        return urlRequest.headers["Authorization"] == bearerToken
    }
}
