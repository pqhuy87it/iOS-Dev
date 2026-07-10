import XCTest
@testable import HybridDesignPattern

final class SearchInteractorTest: XCTestCase {
    private var repository: MockSearchRepository!
    private var sut: SearchInteractor!

    override func setUp() {
        super.setUp()
        repository = MockSearchRepository()
        sut = SearchInteractor(searchRepository: repository)
    }

    override func tearDown() {
        repository = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - searchPhotos

    @MainActor
    func test_searchPhotos_mapsResultDTOToDomain() async throws {
        repository.searchResult = .success(
            DTOFixtures.searchResult(total: 100, totalPages: 10, photoIDs: ["a", "b"])
        )

        let result = try await sut.searchPhotos(query: "cat", page: 1, perPage: 30)

        XCTAssertEqual(result.total, 100)
        XCTAssertEqual(result.totalPages, 10)
        XCTAssertEqual(result.results.map { $0.id }, ["a", "b"])
    }

    func test_searchPhotos_forwardsQuery() async throws {
        _ = try await sut.searchPhotos(query: "sunset", page: 1, perPage: 30)

        XCTAssertEqual(repository.lastQuery, "sunset")
    }

    func test_searchPhotos_repositoryError_propagates() async {
        repository.searchResult = .failure(TestError())

        do {
            _ = try await sut.searchPhotos(query: "cat", page: 1, perPage: 30)
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - getSearchHistory

    func test_getSearchHistory_mapsToKeywordStrings() async throws {
        repository.historyResult = .success([
            DBModel.SearchHistory(keyword: "cat"),
            DBModel.SearchHistory(keyword: "nature")
        ])

        let history = try await sut.getSearchHistory()

        XCTAssertEqual(history, ["cat", "nature"])
    }

    func test_getSearchHistory_empty_returnsEmpty() async throws {
        repository.historyResult = .success([])

        let history = try await sut.getSearchHistory()

        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - saveSearchKeyword

    func test_saveSearchKeyword_forwardsToRepository() async throws {
        try await sut.saveSearchKeyword("cat")

        XCTAssertEqual(repository.savedKeywords, ["cat"])
    }

    func test_saveSearchKeyword_repositoryError_propagates() async {
        repository.saveError = TestError()

        do {
            try await sut.saveSearchKeyword("cat")
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}
