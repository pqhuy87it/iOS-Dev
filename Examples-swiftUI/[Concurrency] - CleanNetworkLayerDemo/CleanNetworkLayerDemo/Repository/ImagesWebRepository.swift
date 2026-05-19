import UIKit
import Foundation

struct ImagesWebRepository: ImagesWebRepositoryProtocol {
    
    private let client: ImageClient
    
    // Inject ImageClient qua hàm init
    init(client: ImageClient = ImageClient()) {
        self.client = client
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        // Repository chỉ làm nhiệm vụ chuyển tiếp URL xuống Client
        return try await client.downloadImage(from: url)
    }
}
