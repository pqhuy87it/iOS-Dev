import XCTest
@testable import HybridDesignPattern

@MainActor
final class TopicsViewModelTest: XCTestCase {

    func test_loadTopics_success_setsLoaded() async {
        let interactor = MockTopicsInteractor()
        interactor.topicsHandler = { _, _ in EntityFixtures.topics([("t1", "nature"), ("t2", "wallpapers")]) }
        let sut = TopicsViewModel(topicsInteractor: interactor)

        sut.send(.loadTopics)
        await waitUntil { sut.state.topics.isSettled }

        XCTAssertEqual(sut.state.topics.value?.count, 2)
        XCTAssertEqual(sut.state.topics.value?.first?.slug, "nature")
    }

    func test_loadTopics_whenAlreadyLoaded_doesNotReload() async {
        let interactor = MockTopicsInteractor()
        interactor.topicsHandler = { _, _ in EntityFixtures.topics([("t1", "nature")]) }
        let sut = TopicsViewModel(topicsInteractor: interactor)

        sut.send(.loadTopics)
        await waitUntil { sut.state.topics.isSettled }
        sut.send(.loadTopics)
        await Task.yield()

        XCTAssertEqual(interactor.topicsCallCount, 1)
    }

    func test_loadTopics_failure_setsFailed() async {
        let interactor = MockTopicsInteractor()
        interactor.topicsHandler = { _, _ in throw TestError() }
        let sut = TopicsViewModel(topicsInteractor: interactor)

        sut.send(.loadTopics)
        await waitUntil { sut.state.topics.error != nil }

        XCTAssertTrue(sut.state.topics.error is TestError)
    }

    func test_refreshTopics_reloadsEvenWhenLoaded() async {
        let interactor = MockTopicsInteractor()
        interactor.topicsHandler = { _, _ in EntityFixtures.topics([("t1", "nature")]) }
        let sut = TopicsViewModel(topicsInteractor: interactor)

        sut.send(.loadTopics)
        await waitUntil { sut.state.topics.isSettled }
        sut.send(.refreshTopics)
        await waitUntil { interactor.topicsCallCount == 2 }

        XCTAssertEqual(interactor.topicsCallCount, 2)
    }
}
