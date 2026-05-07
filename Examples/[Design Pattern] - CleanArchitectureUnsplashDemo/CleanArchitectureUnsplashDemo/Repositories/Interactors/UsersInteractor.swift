import Foundation

protocol UsersInteractor {
    func refreshUsers() async throws
}

struct RealUsersInteractor: UsersInteractor {
    let webRepository: UsersWebRepository
    let dbRepository: UsersDBRepository

    func refreshUsers() async throws {
        // 1. Lấy dữ liệu mới từ Server
        let apiUsers = try await webRepository.fetchUsers()
        // 2. Lưu đè xuống Database cục bộ
        try await dbRepository.store(users: apiUsers)
    }
}
