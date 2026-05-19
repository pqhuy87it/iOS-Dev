import Foundation

protocol UsersInteractor {
    func refreshUsers() async throws
}

struct RealUsersInteractor: UsersInteractor {
    let webRepository: UsersWebRepository
    let dbRepository: UsersDBRepository

    func refreshUsers() async throws {
        // 1. Fetch new data from Server
        let apiUsers = try await webRepository.fetchUsers()
        // 2. Overwrite to local Database
        try await dbRepository.store(users: apiUsers)
    }
}