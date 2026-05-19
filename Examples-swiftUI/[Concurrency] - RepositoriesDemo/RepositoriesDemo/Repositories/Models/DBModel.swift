import Foundation
import SwiftData

// Namespace chứa các model cho database
enum DBModel { }

extension DBModel {
    @Model final class User {
        static let schema = DBModel.User.self
        var id: Int
        var name: String
        var email: String?

        init(id: Int, name: String, email: String? = nil) {
            self.id = id
            self.name = name
            self.email = email
        }
    }
}

extension Schema {
    private static var actualVersion: Schema.Version = Version(1, 0, 0)

    static var appSchema: Schema {
        Schema([
            // Khai báo các class @Model của bạn ở đây
            // DBModel.User.self,
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

// ModelActor dùng chung cho các thao tác Database
@ModelActor
final actor MainDBRepository { }
