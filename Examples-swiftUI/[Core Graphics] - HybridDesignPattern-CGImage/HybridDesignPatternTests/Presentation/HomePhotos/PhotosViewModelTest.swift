import XCTest
@testable import HybridDesignPattern

@MainActor
final class PhotosViewModelTest: XCTestCase {

    func test_loadPhotos_success_setsLoadedAndCanLoadMore() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { _, _ in EntityFixtures.photos(ids: Array(1...30).map(String.init)) }
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }

        XCTAssertEqual(sut.state.photos.value?.count, 30)
        XCTAssertTrue(sut.state.canLoadMore)
    }

    func test_loadPhotos_partialPage_disablesCanLoadMore() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { _, _ in EntityFixtures.photos(ids: ["a", "b"]) }
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }

        XCTAssertEqual(sut.state.photos.value?.count, 2)
        XCTAssertFalse(sut.state.canLoadMore)
    }

    func test_loadPhotos_whenAlreadyLoaded_doesNotReload() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { _, _ in EntityFixtures.photos(ids: ["a"]) }
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }
        sut.send(.loadPhotos)
        await Task.yield()

        XCTAssertEqual(interactor.callCount, 1)
    }

    func test_loadPhotos_failure_setsFailed() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { _, _ in throw TestError() }
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.error != nil }

        XCTAssertTrue(sut.state.photos.error is TestError)
    }

    func test_refreshPhotos_reloadsEvenWhenLoaded() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { _, _ in EntityFixtures.photos(ids: ["a"]) }
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }
        sut.send(.refreshPhotos)
        await waitUntil { interactor.callCount == 2 }

        XCTAssertEqual(interactor.callCount, 2)
    }

    func test_loadMore_appendsNextPage() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { page, _ in
            page == 1
                ? EntityFixtures.photos(ids: (1...30).map { "p\($0)" })
                : EntityFixtures.photos(ids: ["n1", "n2"])
        }
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.value?.count == 30 }

        sut.send(.loadMore)
        await waitUntil { (sut.state.photos.value?.count ?? 0) > 30 }

        XCTAssertEqual(sut.state.photos.value?.count, 32)
        XCTAssertEqual(interactor.requestedPages, [1, 2])
    }

    func test_loadMore_whenCannotLoadMore_isNoOp() async {
        let interactor = MockPhotosInteractor()
        interactor.handler = { _, _ in EntityFixtures.photos(ids: ["a"]) } // partial -> canLoadMore false
        let sut = PhotosViewModel(photosInteractor: interactor)

        sut.send(.loadPhotos)
        await waitUntil { sut.state.photos.isSettled }
        sut.send(.loadMore)
        await Task.yield()

        XCTAssertEqual(interactor.callCount, 1)
    }
}
