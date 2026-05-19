import XCTest
import SwiftData
@testable import CleanArchitectureDemo

final class SearchDBRepositoryTests: XCTestCase {
    
    var container: ModelContainer!
    var sut: MainDBRepository!
    
    @MainActor
    override func setUp() async throws {
        // Initialize in-memory ModelContainer to not affect real data
        let schema = Schema([DBModel.SearchHistory.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        
        // MainDBRepository uses this container
        sut = MainDBRepository(modelContainer: container)
    }
    
    @MainActor
    func test_saveAndFetchHistory() async throws {
        // 1. Save keyword
        try await sut.saveSearchKeyword("SwiftUI")
        try await sut.saveSearchKeyword("Clean Architecture")
        
        // 2. Get history
        let history = try await sut.fetchSearchHistory()
        
        // 3. Check result (sorted newest first)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].keyword, "Clean Architecture")
        XCTAssertEqual(history[1].keyword, "SwiftUI")
    }
    
    @MainActor
    func test_duplicateKeywordUpdatesTimestamp() async throws {
        // 1. Save keyword 1st time
        try await sut.saveSearchKeyword("Nature")
        let firstHistory = try await sut.fetchSearchHistory()
        let firstTimestamp = firstHistory[0].timestamp
        
        // Wait a bit to ensure different timestamps
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // 2. Save that keyword again
        try await sut.saveSearchKeyword("Nature")
        
        // 3. Check if duplicated and timestamp is updated
        let secondHistory = try await sut.fetchSearchHistory()
        XCTAssertEqual(secondHistory.count, 1)
        XCTAssertTrue(secondHistory[0].timestamp > firstTimestamp)
    }
}