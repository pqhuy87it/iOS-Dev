import XCTest
@testable import HybridDesignPattern

final class PhotosRepositoryTest: XCTestCase {
    private var sut: PhotosRepository!

    override func setUp() {
        super.setUp()
        sut = PhotosRepository(session: .mocked())
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        super.tearDown()
    }

    @MainActor
    func test_fetchPhotos_success_decodesDTOs() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200),
             JSONFixtures.photosArray(ids: ["a", "b", "c"]))
        }

        let photos = try await sut.fetchPhotos(page: 1, perPage: 30)

        XCTAssertEqual(photos.count, 3)
        XCTAssertEqual(photos.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(photos.first?.urls.small.absoluteString, "https://example.com/a/small.jpg")
        XCTAssertEqual(photos.first?.user.username, "johndoe")
    }

    func test_fetchPhotos_buildsCorrectRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200),
             JSONFixtures.photosArray(ids: ["a"]))
        }

        _ = try await sut.fetchPhotos(page: 2, perPage: 15)

        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.host, "api.unsplash.com")
        XCTAssertEqual(url.path, "/photos")
        let query = try XCTUnwrap(url.query)
        XCTAssertTrue(query.contains("page=2"))
        XCTAssertTrue(query.contains("per_page=15"))
    }

    func test_fetchPhotos_httpError_throwsHTTPCode() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 404), Data("{}".utf8))
        }

        await assertThrowsAPIError(.httpCode(404)) {
            _ = try await self.sut.fetchPhotos(page: 1, perPage: 30)
        }
    }

    func test_fetchPhotos_invalidJSON_throwsUnexpectedResponse() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200), Data("not json".utf8))
        }

        await assertThrowsAPIError(.unexpectedResponse) {
            _ = try await self.sut.fetchPhotos(page: 1, perPage: 30)
        }
    }
}
