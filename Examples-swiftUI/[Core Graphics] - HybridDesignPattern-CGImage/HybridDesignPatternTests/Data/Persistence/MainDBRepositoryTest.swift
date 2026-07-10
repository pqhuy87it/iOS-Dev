import XCTest
import SwiftData
@testable import HybridDesignPattern

@MainActor
final class MainDBRepositoryTest: XCTestCase {

    private func makeSUT() -> MainDBRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: DBModel.SearchHistory.self, configurations: config)
        return MainDBRepository(modelContainer: container)
    }

    func test_saveKeyword_thenFetch_returnsIt() async throws {
        let sut = makeSUT()

        try await sut.saveSearchKeyword("nature")
        let history = try await sut.fetchSearchHistory()

        XCTAssertEqual(history.map(\.keyword), ["nature"])
    }

    func test_saveKeyword_trimsWhitespace() async throws {
        let sut = makeSUT()

        try await sut.saveSearchKeyword("  cat  ")
        let history = try await sut.fetchSearchHistory()

        XCTAssertEqual(history.map(\.keyword), ["cat"])
    }

    func test_saveKeyword_ignoresBlank() async throws {
        let sut = makeSUT()

        try await sut.saveSearchKeyword("   ")
        let history = try await sut.fetchSearchHistory()

        XCTAssertTrue(history.isEmpty)
    }

    func test_saveKeyword_duplicate_isNotDuplicated() async throws {
        let sut = makeSUT()

        try await sut.saveSearchKeyword("cat")
        try await sut.saveSearchKeyword("cat")
        let history = try await sut.fetchSearchHistory()

        XCTAssertEqual(history.count, 1)
    }

    func test_fetchHistory_sortedByMostRecent() async throws {
        let sut = makeSUT()

        try await sut.saveSearchKeyword("first")
        try await sut.saveSearchKeyword("second")
        try await sut.saveSearchKeyword("first")

        let history = try await sut.fetchSearchHistory()

        XCTAssertEqual(history.map(\.keyword), ["first", "second"])
    }

    func test_fetchHistory_limitedTo15() async throws {
        let sut = makeSUT()

        for i in 1...20 {
            try await sut.saveSearchKeyword("keyword-\(i)")
        }
        let history = try await sut.fetchSearchHistory()

        XCTAssertEqual(history.count, 15)
        XCTAssertEqual(history.first?.keyword, "keyword-20")
    }
}
