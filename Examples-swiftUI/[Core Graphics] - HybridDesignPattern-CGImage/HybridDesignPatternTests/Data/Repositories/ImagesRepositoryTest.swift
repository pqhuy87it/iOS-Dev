import XCTest
import UIKit
@testable import HybridDesignPattern

final class ImagesRepositoryTest: XCTestCase {
    private var sut: ImagesRepository!
    private let imageURL = URL(string: "https://images.unsplash.com/photo-1.jpg")!

    override func setUp() {
        super.setUp()
        sut = ImagesRepository(session: .mocked())
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        super.tearDown()
    }

    func test_loadImage_success_returnsImage() async throws {
        let pngData = Self.makePNGData()
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200), pngData)
        }

        let image = try await sut.loadImage(url: imageURL)

        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func test_loadImage_requestsGivenURL() async throws {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200), Self.makePNGData())
        }

        _ = try await sut.loadImage(url: imageURL)

        XCTAssertEqual(MockURLProtocol.lastRequest?.url, imageURL)
    }

    func test_loadImage_invalidData_throwsImageDeserialization() async {
        MockURLProtocol.requestHandler = { request in
            (HTTPResponseFactory.make(url: request.url, statusCode: 200), Data("not an image".utf8))
        }

        await assertThrowsAPIError(.imageDeserialization) {
            _ = try await self.sut.loadImage(url: self.imageURL)
        }
    }

    func test_loadImage_transportError_propagates() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await sut.loadImage(url: imageURL)
            XCTFail("Expected loadImage to throw")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
    }

    // MARK: - Helpers

    private static func makePNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.pngData()!
    }
}
