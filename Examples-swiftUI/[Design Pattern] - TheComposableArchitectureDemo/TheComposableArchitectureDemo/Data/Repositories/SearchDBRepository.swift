import SwiftData
import Foundation

extension MainDBRepository: SearchDBRepositoryProtocol {
    
    @MainActor
    func fetchSearchHistory() async throws -> [DBModel.SearchHistory] {
        // Get history, sort by latest time (descending)
        var fetchDescriptor = FetchDescriptor<DBModel.SearchHistory>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        fetchDescriptor.fetchLimit = 15 // Only fetch up to 15 latest keywords
        return try modelContainer.mainContext.fetch(fetchDescriptor)
    }

    func saveSearchKeyword(_ keyword: String) async throws {
        let trimmed = keyword.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        try modelContext.transaction {
            // Check if the keyword already exists
            let fetchDescriptor = FetchDescriptor<DBModel.SearchHistory>(
                predicate: #Predicate { $0.keyword == trimmed }
            )
            
            if let existing = try? modelContext.fetch(fetchDescriptor).first {
                // If it exists, update the timestamp so it jumps to the top
                existing.timestamp = Date()
            } else {
                // If not, create new
                let newHistory = DBModel.SearchHistory(keyword: trimmed)
                modelContext.insert(newHistory)
            }
        }
    }
}