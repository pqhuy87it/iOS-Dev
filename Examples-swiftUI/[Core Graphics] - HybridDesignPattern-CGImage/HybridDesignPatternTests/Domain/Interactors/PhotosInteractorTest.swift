import XCTest
@testable import HybridDesignPattern

final class PhotosInteractorTest: XCTestCase {
    private var repository: MockPhotosRepository!
    private var sut: PhotosInteractor!

    override func setUp() {
        super.setUp()
        repository = MockPhotosRepository()
        sut = PhotosInteractor(photosRepository: repository)
    }

    override func tearDown() {
        repository = nil
        sut = nil
        super.tearDown()
    }

    @MainActor
    func test_fetchPhotos_mapsDTOsToDomain() async throws {
        repository.fetchPhotosResult = .success(DTOFixtures.photos(ids: ["a", "b", "c"]))

        let photos = try await sut.fetchPhotos(page: 1, perPage: 10)

        XCTAssertEqual(photos.map { $0.id }, ["a", "b", "c"])
        XCTAssertEqual(photos.first?.urls.small.absoluteString, "https://example.com/a/small.jpg")
        XCTAssertEqual(photos.first?.user.username, "johndoe")
    }

    func test_fetchPhotos_forwardsPagingToRepository() async throws {
        _ = try await sut.fetchPhotos(page: 4, perPage: 25)

        XCTAssertEqual(repository.lastPage, 4)
        XCTAssertEqual(repository.lastPerPage, 25)
        XCTAssertEqual(repository.fetchPhotosCallCount, 1)
    }

    func test_fetchPhotos_emptyResult_returnsEmpty() async throws {
        repository.fetchPhotosResult = .success([])

        let photos = try await sut.fetchPhotos(page: 1, perPage: 10)

        XCTAssertTrue(photos.isEmpty)
    }

    func test_fetchPhotos_repositoryError_propagates() async {
        repository.fetchPhotosResult = .failure(TestError())

        do {
            _ = try await sut.fetchPhotos(page: 1, perPage: 10)
            XCTFail("Expected error to propagate")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
}
