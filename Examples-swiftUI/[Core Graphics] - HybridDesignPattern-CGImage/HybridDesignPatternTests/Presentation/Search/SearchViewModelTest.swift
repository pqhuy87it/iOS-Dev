import XCTest
import Combine
@testable import HybridDesignPattern

@MainActor
final class SearchViewModelTest: XCTestCase {

    private func makeSUT(_ interactor: MockSearchInteractor) -> SearchViewModel {
        SearchViewModel(searchInteractor: interactor, appState: Store<AppState>(AppState()))
    }

    func test_performSearch_success_setsResultsAndCanLoadMore() async {
        let interactor = MockSearchInteractor()
        interactor.searchHandler = { _, _, _ in
            EntityFixtures.searchResult(total: 100, totalPages: 5, photoIDs: ["a", "b"])
        }
        let sut = makeSUT(interactor)

        sut.send(.performSearch("cat"))
        await waitUntil { sut.state.searchResult.value != nil }

        XCTAssertEqual(sut.state.searchResult.value?.count, 2)
        XCTAssertTrue(sut.state.canLoadMore)
        XCTAssertEqual(interactor.savedKeywords, ["cat"])
        XCTAssertEqual(interactor.lastQuery, "cat")
    }

    func test_performSearch_blankQuery_isIgnored() async {
        let interactor = MockSearchInteractor()
        let sut = makeSUT(interactor)

        sut.send(.performSearch("   "))
        await Task.yield()

        XCTAssertEqual(interactor.searchCallCount, 0)
    }

    func test_performSearch_failure_setsFailed() async {
        let interactor = MockSearchInteractor()
        interactor.searchHandler = { _, _, _ in throw TestError() }
        let sut = makeSUT(interactor)

        sut.send(.performSearch("cat"))
        await waitUntil { sut.state.searchResult.error != nil }

        XCTAssertTrue(sut.state.searchResult.error is TestError)
    }

    func test_loadHistory_setsSearchHistory() async {
        let interactor = MockSearchInteractor()
        interactor.historyResult = .success(["cat", "nature"])
        let sut = makeSUT(interactor)

        sut.send(.loadHistory)
        await waitUntil { sut.state.searchHistory == ["cat", "nature"] }

        XCTAssertEqual(sut.state.searchHistory, ["cat", "nature"])
    }

    func test_updateSearchText_empty_clearsResults() async {
        let interactor = MockSearchInteractor()
        interactor.searchHandler = { _, _, _ in
            EntityFixtures.searchResult(total: 10, totalPages: 1, photoIDs: ["a"])
        }
        let sut = makeSUT(interactor)

        sut.send(.performSearch("cat"))
        await waitUntil { sut.state.searchResult.value != nil }

        sut.send(.updateSearchText(""))
        await waitUntil { sut.state.searchResult.isNotRequestedCase }

        XCTAssertTrue(sut.state.searchResult.isNotRequestedCase)
        XCTAssertEqual(sut.state.searchText, "")
    }

    func test_loadMore_appendsNextPage() async {
        let interactor = MockSearchInteractor()
        interactor.searchHandler = { _, page, _ in
            page == 1
                ? EntityFixtures.searchResult(total: 100, totalPages: 5, photoIDs: ["a", "b"])
                : EntityFixtures.searchResult(total: 100, totalPages: 5, photoIDs: ["c"])
        }
        let sut = makeSUT(interactor)

        sut.send(.performSearch("cat"))
        await waitUntil { sut.state.searchResult.value?.count == 2 }

        sut.send(.loadMore)
        await waitUntil { (sut.state.searchResult.value?.count ?? 0) > 2 }

        XCTAssertEqual(sut.state.searchResult.value?.count, 3)
    }
}
