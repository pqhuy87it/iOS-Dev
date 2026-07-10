import XCTest
@testable import HybridDesignPattern

@MainActor
final class PhotoDetailViewModelTest: XCTestCase {

    func test_derivedDisplayData() {
        let photo = EntityFixtures.photos(ids: ["x"])[0]
        let sut = PhotoDetailViewModel(photo: photo)

        XCTAssertEqual(sut.imageURL, photo.urls.regular)
        XCTAssertEqual(sut.authorName, "John Doe")
        XCTAssertEqual(sut.description, "A description")
        XCTAssertEqual(sut.sizeText, "Original size: 4000 x 3000")
    }

    func test_authorName_fallsBackToUsername() {
        let dto = try! JSONDecoder().decode(PhotoDTO.self, from: Data(namelessPhotoJSON.utf8))
        let sut = PhotoDetailViewModel(photo: dto.toDomain())

        XCTAssertEqual(sut.authorName, "johndoe")
    }

    private let namelessPhotoJSON = """
    {
      "id": "x", "width": 100, "height": 200, "color": "#fff",
      "description": null, "alt_description": "alt text",
      "urls": {
        "raw": "https://e.com/r.jpg", "full": "https://e.com/f.jpg",
        "regular": "https://e.com/reg.jpg", "small": "https://e.com/s.jpg", "thumb": "https://e.com/t.jpg"
      },
      "user": {
        "id": "u", "username": "johndoe", "name": null,
        "first_name": null, "last_name": null,
        "instagram_username": null, "twitter_username": null,
        "portfolio_url": null, "total_collections": 0,
        "profile_image": { "small": "https://e.com/s.jpg", "medium": "https://e.com/m.jpg", "large": "https://e.com/l.jpg" },
        "links": { "self": "https://e.com/self", "html": "https://e.com/html", "photos": "https://e.com/photos" }
      }
    }
    """
}
