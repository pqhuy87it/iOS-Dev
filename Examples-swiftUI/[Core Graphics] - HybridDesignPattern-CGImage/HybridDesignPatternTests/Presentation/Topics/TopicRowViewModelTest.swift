import XCTest
@testable import HybridDesignPattern

@MainActor
final class TopicRowViewModelTest: XCTestCase {

    private func makeTopic() -> Topic {
        EntityFixtures.topics([("t1", "nature")])[0]
    }

    func test_loadPhotos_success_usesTopicSlug() async {
        let interactor = MockTopicsInteractor()
        interactor.topicPhotosHandler = { _, _, _ in EntityFixtures.photos(ids: ["p1", "p2"]) }
        let sut = TopicRowViewModel(topic: makeTopic(), topicsInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }

        XCTAssertEqual(sut.state.photos.value?.count, 2)
        XCTAssertEqual(interactor.lastSlug, "nature")
    }

    func test_loadPhotos_whenAlreadyLoaded_isNoOp() async {
        let interactor = MockTopicsInteractor()
        var callCount = 0
        interactor.topicPhotosHandler = { _, _, _ in
            callCount += 1
            return EntityFixtures.photos(ids: ["p1"])
        }
        let sut = TopicRowViewModel(topic: makeTopic(), topicsInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }
        sut.send(.loadPhotos)
        await Task.yield()

        XCTAssertEqual(callCount, 1)
    }

    func test_loadPhotos_failure_setsFailed() async {
        let interactor = MockTopicsInteractor()
        interactor.topicPhotosHandler = { _, _, _ in throw TestError() }
        let sut = TopicRowViewModel(topic: makeTopic(), topicsInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.error != nil }

        XCTAssertTrue(sut.state.photos.error is TestError)
    }
}
