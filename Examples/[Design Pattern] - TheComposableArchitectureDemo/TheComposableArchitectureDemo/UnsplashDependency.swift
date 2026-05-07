import ComposableArchitecture
import Foundation

// 1. Tạo Dependency Key
private enum UnsplashRepositoryKey: DependencyKey {
    // liveValue là instance sẽ chạy khi app hoạt động thật
    static let liveValue: UnsplashWebRepositoryProtocol = UnsplashWebRepository(session: .shared)
    
    // previewValue dùng khi bạn xem Canvas Preview (tránh gọi API thật tốn request)
    // Ở đây bạn có thể tận dụng luôn cái StubPhotoInteractor (hoặc tạo một StubWebRepository tương tự)
    static let previewValue: UnsplashWebRepositoryProtocol = StubWebRepository()
}

// 2. Mở rộng DependencyValues để TCA có thể nhận diện
extension DependencyValues {
    var unsplashRepository: UnsplashWebRepositoryProtocol {
        get { self[UnsplashRepositoryKey.self] }
        set { self[UnsplashRepositoryKey.self] = newValue }
    }
}

// (Tuỳ chọn) Tạo nhanh 1 mock cho Preview
struct StubWebRepository: UnsplashWebRepositoryProtocol {
    // 1. Thêm 2 biến bắt buộc để conform với WebRepositoryProtocol
    var session: URLSession = .shared
    var baseURL: String = ""
    
    func fetchLatestPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo] { return [] }
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult { return .init(total: 0, totalPages: 0, results: []) }
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic] { return [] }
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo] { return [] }
}
