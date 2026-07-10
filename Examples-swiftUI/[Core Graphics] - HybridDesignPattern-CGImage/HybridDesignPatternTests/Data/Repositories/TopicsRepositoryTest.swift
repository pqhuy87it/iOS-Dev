import XCTest
@testable import HybridDesignPattern

final class TopicsRepositoryTest: XCTestCase {
    private var sut: TopicsRepository!

    override func setUp() {
        super.setUp()
        sut = TopicsRepository(session: .mocked())
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        super.tearDown()
    }

    // MARK: - fetchTopics

    func test_fetchTopics_success_decodesDTOs() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200),
             JSONFixtures.topicsArray([("t1", "nature"), ("t2", "wallpapers")]))
        }

        let topics = try await sut.fetchTopics(page: 1, perPage: 10)

        XCTAssertEqual(topics.map(\.id), ["t1", "t2"])
        XCTAssertEqual(topics.first?.slug, "nature")
        XCTAssertEqual(topics.first?.coverPhoto?.id, "cover-t1")
    }

    func test_fetchTopics_buildsCorrectRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200),
             JSONFixtures.topicsArray([("t1", "nature")]))
        }

        _ = try await sut.fetchTopics(page: 3, perPage: 5)

        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.path, "/topics")
        let query = try XCTUnwrap(url.query)
        XCTAssertTrue(query.contains("page=3"))
        XCTAssertTrue(query.contains("per_page=5"))
    }

    func test_fetchTopics_httpError_throwsHTTPCode() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 500), Data("{}".utf8))
        }

        await assertThrowsAPIError(.httpCode(500)) {
            _ = try await self.sut.fetchTopics(page: 1, perPage: 10)
        }
    }

    // MARK: - fetchTopicPhotos

    func test_fetchTopicPhotos_success_decodesDTOs() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200),
             JSONFixtures.photosArray(ids: ["p1", "p2"]))
        }

        let photos = try await sut.fetchTopicPhotos(slug: "nature", page: 1, perPage: 10)

        XCTAssertEqual(photos.map(\.id), ["p1", "p2"])
    }

    func test_fetchTopicPhotos_buildsSlugPath() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200),
             JSONFixtures.photosArray(ids: ["p1"]))
        }

        _ = try await sut.fetchTopicPhotos(slug: "nature", page: 1, perPage: 10)

        let url = try XCTUnwrap(MockURLProtocol.lastRequest?.url)
        XCTAssertEqual(url.path, "/topics/nature/photos")
    }

    func test_fetchTopicPhotos_invalidJSON_throwsUnexpectedResponse() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200), Data("<html/>".utf8))
        }

        await assertThrowsAPIError(.unexpectedResponse) {
            _ = try await self.sut.fetchTopicPhotos(slug: "nature", page: 1, perPage: 10)
        }
    }
}
