import Foundation
@testable import CleanArchitectureDemo

extension ApiModel.Photo {
    static func mock(id: String = "1") -> ApiModel.Photo {
        return ApiModel.Photo(
            id: id,
            width: 100,
            height: 100,
            color: "#000000",
            description: "Description",
            altDescription: "Alt Description",
            urls: ApiModel.PhotoUrls(
                raw: URL(string: "https://example.com")!,
                full: URL(string: "https://example.com")!,
                regular: URL(string: "https://example.com")!,
                small: URL(string: "https://example.com")!,
                thumb: URL(string: "https://example.com")!
            ),
            user: ApiModel.User(id: "u1", username: "user", name: "User")
        )
    }
}
