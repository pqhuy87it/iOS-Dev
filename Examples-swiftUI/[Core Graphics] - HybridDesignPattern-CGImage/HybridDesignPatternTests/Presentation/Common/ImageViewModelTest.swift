import XCTest
import UIKit
@testable import HybridDesignPattern

@MainActor
final class ImageViewModelTest: XCTestCase {
    private let url = URL(string: "https://images.unsplash.com/photo-1.jpg")!

    func test_onAppear_success_loadsImage() async {
        let interactor = MockImagesInteractor()
        interactor.result = .success(Self.makeImage())
        let sut = ImageViewModel(imageURL: url, interactor: interactor)

        sut.send(.onAppear)
        await waitUntil { sut.state.image.isSettled }

        XCTAssertNotNil(sut.state.image.value)
        XCTAssertEqual(interactor.lastURL, url)
    }

    func test_onAppear_failure_setsFailed() async {
        let interactor = MockImagesInteractor()
        interactor.result = .failure(TestError())
        let sut = ImageViewModel(imageURL: url, interactor: interactor)

        sut.send(.onAppear)
        await waitUntil { sut.state.image.error != nil }

        XCTAssertTrue(sut.state.image.error is TestError)
    }

    func test_onAppear_whenAlreadyLoaded_doesNotReload() async {
        let interactor = MockImagesInteractor()
        interactor.result = .success(Self.makeImage())
        let sut = ImageViewModel(imageURL: url, interactor: interactor)

        sut.send(.onAppear)
        await waitUntil { sut.state.image.isSettled }
        interactor.result = .failure(TestError())
        sut.send(.onAppear)
        await Task.yield()

        XCTAssertNotNil(sut.state.image.value)
        XCTAssertNil(sut.state.image.error)
    }

    private static func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
    }
}
