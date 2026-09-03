import Foundation
import UIKit

struct ImagesRepository: ImagesRepositoryProtocol {

    let apiClient: ApiClient

    init(apiClient: ApiClient = .shared) {
        self.apiClient = apiClient
    }

    func loadImage(url: URL) async throws -> UIImage {
        let data = try await apiClient.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw APIError.imageDeserialization
        }
        
        return image
    }
}

struct StubImagesInteractor: ImagesInteractorProtocol {
    let shouldFail: Bool
    
    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        if shouldFail {
            throw NSError(domain: "StubError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load mock image"])
        }
        
        let placeholderImage = UIImage(systemName: "photo.artframe") ?? UIImage()
        
        return placeholderImage
    }
}
