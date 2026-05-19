import Foundation
import SwiftData

protocol UsersDBRepository {
    @MainActor
    func fetchLocalUsers() async throws -> [DBModel.User]
    func store(users: [ApiModel.User]) async throws
}

// Sử dụng MainDBRepository (ModelActor) để implement giao thức này
extension MainDBRepository: UsersDBRepository {

    @MainActor
    func fetchLocalUsers() async throws -> [DBModel.User] {
        let fetchDescriptor = FetchDescriptor<DBModel.User>()
        return try modelContainer.mainContext.fetch(fetchDescriptor)
    }

    func store(users: [ApiModel.User]) async throws {
        // Transaction giúp lưu hàng loạt an toàn
        try modelContext.transaction {
            // Xóa dữ liệu cũ nếu cần, hoặc lưu mới
            users
                .map { $0.dbModel() }
                .forEach { modelContext.insert($0) }
        }
    }
}

// Hàm mapping từ ApiModel (Network) sang DBModel (Local)
internal extension ApiModel.User {
    func dbModel() -> DBModel.User {
        return DBModel.User(id: id, name: name, email: email)
    }
}
