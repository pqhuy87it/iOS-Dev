import Foundation
import XCTest
@testable import HybridDesignPattern

/// Confirm that the `block` throws the expected `APIError`.
func assertThrowsAPIError(
    _ expected: APIError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ block: () async throws -> Void
) async {
    do {
        try await block()
        XCTFail("Expected to throw APIError.\(expected)", file: file, line: line)
    } catch let error as APIError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Expected APIError.\(expected) but got \(error)", file: file, line: line)
    }
}

/// Block all URLSession requests in the test and return the response/data configured by the test.
// Use this for both `session.data(for:)` and `session.download(from:)`.
final class MockURLProtocol: URLProtocol {
    /// (request) -> (response, body). Throw an error to simulate a transport error.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    /// Save the last request so that the tester can check the URL/headers.
    nonisolated(unsafe) static var lastRequest: URLRequest?

    static func reset() {
        requestHandler = nil
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequest = request

        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test helpers

extension URLSession {
    /// URLSession only goes through MockURLProtocol (it doesn't touch the real network).
    static func mocked() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}

enum HTTPResponseFactory {
    static func make(url: URL?, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url ?? URL(string: "https://api.unsplash.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

// MARK: - JSON

enum JSONFixtures {
    /// A valid PhotoDTO object (with nested user and URLs).
    static func photo(id: String = "photo-1") -> String {
        """
        {
          "id": "\(id)",
          "width": 4000,
          "height": 3000,
          "color": "#60544D",
          "description": "A description",
          "alt_description": "An alt description",
          "urls": {
            "raw": "https://example.com/\(id)/raw.jpg",
            "full": "https://example.com/\(id)/full.jpg",
            "regular": "https://example.com/\(id)/regular.jpg",
            "small": "https://example.com/\(id)/small.jpg",
            "thumb": "https://example.com/\(id)/thumb.jpg"
          },
          "user": {
            "id": "user-\(id)",
            "username": "johndoe",
            "name": "John Doe",
            "first_name": "John",
            "last_name": "Doe",
            "instagram_username": "insta",
            "twitter_username": "tw",
            "portfolio_url": "https://example.com/portfolio",
            "total_collections": 3,
            "profile_image": {
              "small": "https://example.com/u/s.jpg",
              "medium": "https://example.com/u/m.jpg",
              "large": "https://example.com/u/l.jpg"
            },
            "links": {
              "self": "https://example.com/u/self",
              "html": "https://example.com/u/html",
              "photos": "https://example.com/u/photos"
            }
          }
        }
        """
    }

    /// PhotoDTO.
    static func photosArray(ids: [String]) -> Data {
        let objects = ids.map { photo(id: $0) }.joined(separator: ",")
        return Data("[\(objects)]".utf8)
    }

    /// A TopicDTO object (with cover_photo).
    static func topic(id: String, slug: String) -> String {
        """
        {
          "id": "\(id)",
          "slug": "\(slug)",
          "title": "Title \(id)",
          "description": "Topic description",
          "cover_photo": \(photo(id: "cover-\(id)"))
        }
        """
    }

    /// TopicDTO.
    static func topicsArray(_ topics: [(id: String, slug: String)]) -> Data {
        let objects = topics.map { topic(id: $0.id, slug: $0.slug) }.joined(separator: ",")
        return Data("[\(objects)]".utf8)
    }

    /// SearchResultDTO.
    static func searchResult(total: Int, totalPages: Int, photoIDs: [String]) -> Data {
        let results = photoIDs.map { photo(id: $0) }.joined(separator: ",")
        return Data(
            """
            {
              "total": \(total),
              "total_pages": \(totalPages),
              "results": [\(results)]
            }
            """.utf8
        )
    }
}
