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

// Cập nhật lại StubImagesInteractor
struct StubImagesInteractor: ImagesInteractorProtocol {
    
    // Bạn có thể tuỳ chỉnh ảnh trả về hoặc thêm cờ (flag) để test trường hợp lỗi
    let shouldFail: Bool
    
    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }
    
    func loadImage(url: URL) async throws -> UIImage {
        // Mô phỏng độ trễ của mạng (ví dụ: 0.5 giây) để test trạng thái .isLoading trên Preview
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Mô phỏng lỗi nếu cần test trạng thái .failed
        if shouldFail {
            throw NSError(domain: "StubError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load mock image"])
        }
        
        // Trả về một ảnh placeholder từ SF Symbols
        // Nếu không tìm thấy, trả về một ảnh trống UIImage()
        let placeholderImage = UIImage(systemName: "photo.artframe") ?? UIImage()
        
        return placeholderImage
    }
}
