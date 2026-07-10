import XCTest
import UIKit
@testable import HybridDesignPattern

final class ImagesInteractorTest: XCTestCase {
    private let url = URL(string: "https://images.unsplash.com/photo-1.jpg")!

    func test_loadImage_returnsImageFromRepository() async throws {
        let expected = Self.makeImage()
        let repository = MockImagesRepository(result: .success(expected))
        let sut = ImagesInteractor(repository: repository)

        let image = try await sut.loadImage(url: url)

        XCTAssertEqual(image.pngData(), expected.pngData())
    }

    func test_loadImage_forwardsURLToRepository() async throws {
        let repository = MockImagesRepository(result: .success(Self.makeImage()))
        let sut = ImagesInteractor(repository: repository)

        _ = try await sut.loadImage(url: url)

        XCTAssertEqual(repository.lastURL, url)
    }

    func test_loadImage_repositoryError_propagates() async {
        let repository = MockImagesRepository(result: .failure(TestError()))
        let sut = ImagesInteractor(repository: repository)

        do {
            _ = try await sut.loadImage(url: url)
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - Helpers

    private static func makeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }
}
