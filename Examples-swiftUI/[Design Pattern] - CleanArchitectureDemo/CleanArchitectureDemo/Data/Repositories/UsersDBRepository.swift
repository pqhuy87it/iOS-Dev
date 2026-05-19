import Foundation
import SwiftData

protocol UsersDBRepository {
    @MainActor
    func fetchLocalUsers() async throws -> [DBModel.User]
    func store(users: [ApiModel.User]) async throws
}
//
//// Use MainDBRepository (ModelActor) to implement this protocol
//extension MainDBRepository: UsersDBRepository {
//
//    @MainActor
//    func fetchLocalUsers() async throws -> [DBModel.User] {
//        let fetchDescriptor = FetchDescriptor<DBModel.User>()
//        return try modelContainer.mainContext.fetch(fetchDescriptor)
//    }
//
//    func store(users: [ApiModel.User]) async throws {
//        // Transaction helps save batches safely
//        try modelContext.transaction {
//            // Delete old data if necessary, or save new
//            users
//                .map { $0.dbModel() }
//                .forEach { modelContext.insert($0) }
//        }
//    }
//}
//
//// Mapping function from ApiModel (Network) to DBModel (Local)
//internal extension ApiModel.User {
//    func dbModel() -> DBModel.User {
//        return DBModel.User(id: id, name: name, email: email)
//    }
//}