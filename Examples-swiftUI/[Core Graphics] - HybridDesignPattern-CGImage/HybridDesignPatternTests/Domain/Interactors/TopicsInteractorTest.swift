import XCTest
@testable import HybridDesignPattern

final class TopicsInteractorTest: XCTestCase {
    private var repository: MockTopicsRepository!
    private var sut: TopicsInteractor!

    override func setUp() {
        super.setUp()
        repository = MockTopicsRepository()
        sut = TopicsInteractor(topicsRepository: repository)
    }

    override func tearDown() {
        repository = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - fetchTopics

    @MainActor
    func test_fetchTopics_mapsDTOsToDomain() async throws {
        repository.topicsResult = .success(DTOFixtures.topics([("t1", "nature"), ("t2", "wallpapers")]))

        let topics = try await sut.fetchTopics(page: 1, perPage: 10)

        XCTAssertEqual(topics.map { $0.id }, ["t1", "t2"])
        XCTAssertEqual(topics.first?.slug, "nature")
        XCTAssertEqual(topics.first?.coverPhoto?.id, "cover-t1")
    }

    func test_fetchTopics_forwardsPaging() async throws {
        _ = try await sut.fetchTopics(page: 2, perPage: 5)

        XCTAssertEqual(repository.lastTopicsPage, 2)
        XCTAssertEqual(repository.lastTopicsPerPage, 5)
    }

    func test_fetchTopics_repositoryError_propagates() async {
        repository.topicsResult = .failure(TestError())

        do {
            _ = try await sut.fetchTopics(page: 1, perPage: 10)
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - fetchTopicPhotos

    @MainActor
    func test_fetchTopicPhotos_mapsDTOsToDomain() async throws {
        repository.topicPhotosResult = .success(DTOFixtures.photos(ids: ["p1", "p2"]))

        let photos = try await sut.fetchTopicPhotos(slug: "nature", page: 1, perPage: 30)

        XCTAssertEqual(photos.map { $0.id }, ["p1", "p2"])
    }

    func test_fetchTopicPhotos_forwardsSlugAndPaging() async throws {
        _ = try await sut.fetchTopicPhotos(slug: "nature", page: 3, perPage: 12)

        XCTAssertEqual(repository.lastSlug, "nature")
        XCTAssertEqual(repository.lastPhotosPage, 3)
        XCTAssertEqual(repository.lastPhotosPerPage, 12)
    }

    func test_fetchTopicPhotos_repositoryError_propagates() async {
        repository.topicPhotosResult = .failure(TestError())

        do {
            _ = try await sut.fetchTopicPhotos(slug: "nature", page: 1, perPage: 30)
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}
