import ComposableArchitecture
import Foundation
import SwiftData

@DependencyClient
struct SearchDatabaseClient {
    var getHistory: () async throws -> [String]
    var saveKeyword: (_ keyword: String) async throws -> Void
}

extension SearchDatabaseClient: DependencyKey {
    // Lưu ý: liveValue thực tế của bạn có thể cần inject ModelContainer từ AppEnvironment,
    // Ở đây tôi viết mô phỏng cách gọi. Bạn có thể điều chỉnh lại chỗ khởi tạo MainDBRepository cho khớp dự án.
    static let liveValue: SearchDatabaseClient = {
        // 1. Khởi tạo ModelContainer dùng chung.
        // Vì 'liveValue' là static let, đoạn code này chỉ chạy đúng 1 lần khi app khởi chạy,
        // đảm bảo bạn chỉ có 1 instance của ModelContainer và DBRepository.
        let container: ModelContainer
        do {
            container = try ModelContainer.appModelContainer()
        } catch {
            // Fallback sang in-memory nếu lỗi (giống cách bạn làm trong AppEnvironment cũ)
            container = try! ModelContainer.appModelContainer(inMemoryOnly: true)
        }
        
        let repository = MainDBRepository(modelContainer: container)
        
        return Self(
            getHistory: {
                // Lấy dữ liệu từ DB (DBModel.SearchHistory)
                let dbHistory = try await repository.fetchSearchHistory()
                // Map sang mảng String để Reducer sử dụng dễ dàng
                return dbHistory.map { $0.keyword }
            },
            saveKeyword: { keyword in
                // Lưu từ khóa mới vào DB
                try await repository.saveSearchKeyword(keyword)
            }
        )
    }()
    
    static let previewValue = Self(
        getHistory: { ["Cat", "Nature", "Space"] },
        saveKeyword: { _ in }
    )
}

extension DependencyValues {
    var searchDatabaseClient: SearchDatabaseClient {
        get { self[SearchDatabaseClient.self] }
        set { self[SearchDatabaseClient.self] = newValue }
    }
}
