import XCTest
@testable import HybridDesignPattern

@MainActor
final class DTOMappingTest: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // MARK: - PhotoDTO -> Photo

    func test_photoDTO_toDomain_mapsAllFields() throws {
        let dto = try decode(PhotoDTO.self, JSONFixtures.photo(id: "x"))
        let photo = dto.toDomain()

        XCTAssertEqual(photo.id, "x")
        XCTAssertEqual(photo.width, 4000)
        XCTAssertEqual(photo.height, 3000)
        XCTAssertEqual(photo.color, "#60544D")
        XCTAssertEqual(photo.description, "A description")
        XCTAssertEqual(photo.altDescription, "An alt description")
        XCTAssertEqual(photo.urls.raw.absoluteString, "https://example.com/x/raw.jpg")
        XCTAssertEqual(photo.urls.small.absoluteString, "https://example.com/x/small.jpg")
        XCTAssertEqual(photo.urls.thumb.absoluteString, "https://example.com/x/thumb.jpg")
    }

    func test_photoDTO_toDomain_mapsNestedUser() throws {
        let dto = try decode(PhotoDTO.self, JSONFixtures.photo(id: "x"))
        let user = dto.toDomain().user

        XCTAssertEqual(user.id, "user-x")
        XCTAssertEqual(user.username, "johndoe")
        XCTAssertEqual(user.name, "John Doe")
        XCTAssertEqual(user.firstName, "John")
        XCTAssertEqual(user.lastName, "Doe")
        XCTAssertEqual(user.instagramUsername, "insta")
        XCTAssertEqual(user.twitterUsername, "tw")
        XCTAssertEqual(user.totalCollections, 3)
        XCTAssertEqual(user.profileImage.small.absoluteString, "https://example.com/u/s.jpg")
        XCTAssertEqual(user.profileImage.large.absoluteString, "https://example.com/u/l.jpg")
    }

    // MARK: - TopicDTO -> Topic

    func test_topicDTO_toDomain_mapsFieldsAndCoverPhoto() throws {
        let dto = try decode(TopicDTO.self, JSONFixtures.topic(id: "t1", slug: "nature"))
        let topic = dto.toDomain()

        XCTAssertEqual(topic.id, "t1")
        XCTAssertEqual(topic.slug, "nature")
        XCTAssertEqual(topic.title, "Title t1")
        XCTAssertEqual(topic.description, "Topic description")
        XCTAssertEqual(topic.coverPhoto?.id, "cover-t1")
    }

    // MARK: - SearchResultDTO -> SearchResult

    func test_searchResultDTO_toDomain_mapsFieldsAndResults() throws {
        let dto = try JSONDecoder().decode(
            SearchResultDTO.self,
            from: JSONFixtures.searchResult(total: 5, totalPages: 2, photoIDs: ["a", "b"])
        )
        let result = dto.toDomain()

        XCTAssertEqual(result.total, 5)
        XCTAssertEqual(result.totalPages, 2)
        XCTAssertEqual(result.results.map { $0.id }, ["a", "b"])
    }
}
