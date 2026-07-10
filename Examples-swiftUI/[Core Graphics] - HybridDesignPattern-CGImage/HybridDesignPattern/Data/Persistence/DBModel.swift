import Foundation
import SwiftData

// Namespace containing models for the database
enum DBModel { }

extension DBModel {
    @Model final class SearchHistory {
        @Attribute(.unique) var keyword: String
        var timestamp: Date

        init(keyword: String, timestamp: Date = Date()) {
            self.keyword = keyword
            self.timestamp = timestamp
        }
    }
}

extension Schema {
    private static var actualVersion: Schema.Version = Version(1, 0, 0)

    // Declare your @Model classes here
    static var appSchema: Schema {
        Schema([
            DBModel.SearchHistory.self
        ], version: actualVersion)
    }
}

extension ModelContainer {
    static func appModelContainer(inMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema.appSchema
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemoryOnly)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
