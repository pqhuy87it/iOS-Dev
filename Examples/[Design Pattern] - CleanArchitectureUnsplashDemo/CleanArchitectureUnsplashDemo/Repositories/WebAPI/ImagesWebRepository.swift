import Foundation
import UIKit

struct ImagesWebRepository: ImagesWebRepositoryProtocol {

    let session: URLSession
    let baseURL: String
    
    init(session: URLSession) {
        self.session = session
        self.baseURL = ""
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        let (localURL, _) = try await session.download(from: url)
        let data = try Data(contentsOf: localURL)
        guard let image = UIImage(data: data) else {
            throw APIError.imageDeserialization
        }
        return image
    }
}
