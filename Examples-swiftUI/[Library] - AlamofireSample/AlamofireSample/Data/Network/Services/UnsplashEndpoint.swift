//
//  UnsplashEndpoint.swift
//  AlamofireSample
//
//  Small builder shared by the Unsplash repositories. Centralizes the base URL
//  and the `Client-ID` auth headers Unsplash requires, so each endpoint enum
//  only has to describe its own path.
//

import Foundation
import Alamofire

enum Unsplash {
    static let baseURL = "https://api.unsplash.com"

    /// Builds a `URLRequest` for an Unsplash endpoint. `path` may already contain
    /// a query string (e.g. `"/photos?page=1"`), matching how the endpoints
    /// describe themselves.
    static func makeRequest(path: String,
                            method: HTTPMethod = .get,
                            clientId: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.method = method
        request.headers = HTTPHeaders([
            "Accept-Version": "v1",
            "Authorization": "Client-ID \(clientId)",
            "Accept": "application/json",
        ])
        return request
    }
}
