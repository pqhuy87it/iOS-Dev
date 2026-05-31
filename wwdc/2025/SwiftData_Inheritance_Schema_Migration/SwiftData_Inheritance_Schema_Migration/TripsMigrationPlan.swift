import SwiftData

enum TripsMigrationPlan: SchemaMigrationPlan {
    // Định nghĩa các schema qua từng phiên bản
    static var schemas: [any VersionedSchema.Type] {
        [TripsSchemaV1.self, TripsSchemaV2.self]
    }
    
    // Định nghĩa các giai đoạn di chuyển
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    // Giai đoạn Lightweight Migration
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: TripsSchemaV1.self,
        toVersion: TripsSchemaV2.self
    )
}

// Giả lập phiên bản 1 (Chỉ có Trip)
enum TripsSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Trip.self] // Ở v1 chưa có subclass
    }
}

// Phiên bản 2 (Hỗ trợ Inheritance)
enum TripsSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Trip.self, PersonalTrip.self, BusinessTrip.self]
    }
}
