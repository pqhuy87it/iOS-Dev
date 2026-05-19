import ComposableArchitecture
import UIKit

// 1. Khai báo Key
private enum ImagesRepositoryKey: DependencyKey {
    // Gọi thẳng Repository cũ của bạn
    static let liveValue: ImagesWebRepositoryProtocol = ImagesWebRepository(session: .shared)
    
    // Tạo 1 stub đơn giản cho Preview đỡ lỗi
    static let previewValue: ImagesWebRepositoryProtocol = StubImagesRepository()
}

// 2. Mở rộng hệ thống Dependency
extension DependencyValues {
    var imagesRepository: ImagesWebRepositoryProtocol {
        get { self[ImagesRepositoryKey.self] }
        set { self[ImagesRepositoryKey.self] = newValue }
    }
}

// Stub giả lập trả về 1 ảnh rỗng hoặc system image cho Preview
struct StubImagesRepository: ImagesWebRepositoryProtocol {
    // 1. Thêm 2 biến bắt buộc để conform với WebRepositoryProtocol
    var session: URLSession = .shared
    var baseURL: String = ""
    
    func loadImage(url: URL) async throws -> UIImage {
        return UIImage(systemName: "photo") ?? UIImage()
    }
}
