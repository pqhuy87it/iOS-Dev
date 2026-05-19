//
//  UsersWebRepository.swift
//  RepositoriesDemo
//
//  Created by huy on 2026/04/17.
//

import Foundation

protocol UsersWebRepository: WebRepository {
    func fetchUsers() async throws -> [ApiModel.User]
}

struct RealUsersWebRepository: UsersWebRepository {
    let session: URLSession
    let baseURL: String

    init(session: URLSession, baseURL: String = "https://api.example.com/v1") {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchUsers() async throws -> [ApiModel.User] {
        return try await call(endpoint: API.getUsers)
    }
}

// Định nghĩa các endpoint riêng cho User
extension RealUsersWebRepository {
    enum API {
        case getUsers
        case createUser(payload: Data)
    }
}

extension RealUsersWebRepository.API: APICall {
    var path: String {
        switch self {
        case .getUsers, .createUser:
            return "/users"
        }
    }
    var method: String {
        switch self {
        case .getUsers: return "GET"
        case .createUser: return "POST"
        }
    }
    var headers: [String: String]? {
        return ["Accept": "application/json", "Content-Type": "application/json"]
    }
    func body() throws -> Data? {
        switch self {
        case .getUsers: return nil
        case let .createUser(payload): return payload
        }
    }
}
