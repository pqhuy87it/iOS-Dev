import XCTest
@testable import CleanArchitectureDemo

final class UnsplashWebRepositoryTests: XCTestCase {
    
    var sut: UnsplashWebRepository!
    var session: URLSession!
    
    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        sut = UnsplashWebRepository(session: session)
    }
    
    override func tearDown() {
        sut = nil
        session = nil
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }
    
    func test_fetchLatestPhotos_success() async throws {
        // Given
        let mockData = """
        [
            {
                "id": "1",
                "width": 100,
                "height": 100,
                "color": "#000000",
                "description": "Test",
                "alt_description": "Alt Test",
                "urls": {
                    "raw": "https://example.com",
                    "full": "https://example.com",
                    "regular": "https://example.com",
                    "small": "https://example.com",
                    "thumb": "https://example.com"
                },
                "user": {
                    "id": "u1",
                    "username": "user",
                    "name": "User"
                }
            }
        ]
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, mockData)
        }
        
        // When
        let photos = try await sut.fetchLatestPhotos(page: 1, perPage: 10)
        
        // Then
        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos[0].id, "1")
        XCTAssertEqual(photos[0].altDescription, "Alt Test")
    }
    
    func test_fetchLatestPhotos_httpError() async {
        // Given
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        // When/Then
        do {
            _ = try await sut.fetchLatestPhotos(page: 1, perPage: 10)
            XCTFail("Should have thrown an error")
        } catch let error as APIError {
            if case .httpCode(let code) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - MockURLProtocol
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool { return true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler is nil")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}
