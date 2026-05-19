import XCTest
@testable import CleanArchitectureDemo

final class PhotoInteractorTests: XCTestCase {
    
    var sut: PhotoInteractor!
    var mockWebRepository: MockUnsplashWebRepository!
    var mockDBRepository: MockSearchDBRepository!
    
    override func setUp() {
        super.setUp()
        mockWebRepository = MockUnsplashWebRepository()
        mockDBRepository = MockSearchDBRepository()
        sut = PhotoInteractor(webRepository: mockWebRepository, dbRepository: mockDBRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockWebRepository = nil
        mockDBRepository = nil
        super.tearDown()
    }
    
    func test_fetchPhotos_success() async throws {
        // Given
        let mockApiModelPhotos = [ApiModel.Photo.mock(id: "1"), ApiModel.Photo.mock(id: "2")]
        mockWebRepository.photosToReturn = mockApiModelPhotos
        
        // When
        let photos = try await sut.fetchPhotos(page: 1, perPage: 10)
        
        // Then
        XCTAssertEqual(photos.count, 2)
        XCTAssertEqual(photos[0].id, "1")
        XCTAssertEqual(photos[1].id, "2")
    }
    
    func test_fetchPhotos_failure() async {
        // Given
        mockWebRepository.errorToThrow = NSError(domain: "test", code: 0)
        
        // When/Then
        do {
            _ = try await sut.fetchPhotos(page: 1, perPage: 10)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func test_saveSearchKeyword() async throws {
        // Given
        let keyword = "Nature"
        
        // When
        try await sut.saveSearchKeyword(keyword)
        
        // Then
        XCTAssertEqual(mockDBRepository.savedKeyword, keyword)
    }
    
    func test_getSearchHistory() async throws {
        // Given
        // Note: Need to Mock DBModel.SearchHistory, but it is a SwiftData Model
        // In Interactor unit test, we mock DBRepository to return keyword strings or mock models.
        // However, Interactor maps from DBModel to String.
        // Because DBModel.SearchHistory is a @Model class, initializing it in tests might require ModelContainer.
        // But here we only test mapping.
        
        let history = [
            DBModel.SearchHistory(keyword: "Cat"),
            DBModel.SearchHistory(keyword: "Dog")
        ]
        mockDBRepository.historyToReturn = history
        
        // When
        let result = try await sut.getSearchHistory()
        
        // Then
        XCTAssertEqual(result, ["Cat", "Dog"])
    }
}