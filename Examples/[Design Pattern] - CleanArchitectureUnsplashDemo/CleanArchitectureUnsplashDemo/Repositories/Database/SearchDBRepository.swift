import SwiftData
import Foundation

extension MainDBRepository: SearchDBRepositoryProtocol {
    
    @MainActor
    func fetchSearchHistory() async throws -> [DBModel.SearchHistory] {
        // Lấy lịch sử, sắp xếp theo thời gian mới nhất (giảm dần)
        var fetchDescriptor = FetchDescriptor<DBModel.SearchHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = 15 // Chỉ lấy tối đa 15 từ khóa gần nhất
        return try modelContainer.mainContext.fetch(fetchDescriptor)
    }

    func saveSearchKeyword(_ keyword: String) async throws {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        try modelContext.transaction {
            // Kiểm tra xem từ khóa đã tồn tại chưa
            let fetchDescriptor = FetchDescriptor<DBModel.SearchHistory>(
                predicate: #Predicate { $0.keyword == trimmed }
            )
            
            if let existing = try? modelContext.fetch(fetchDescriptor).first {
                // Nếu đã có, cập nhật lại thời gian để nó nhảy lên đầu
                existing.timestamp = Date()
            } else {
                // Nếu chưa có, tạo mới
                let newHistory = DBModel.SearchHistory(keyword: trimmed)
                modelContext.insert(newHistory)
            }
        }
    }
}
