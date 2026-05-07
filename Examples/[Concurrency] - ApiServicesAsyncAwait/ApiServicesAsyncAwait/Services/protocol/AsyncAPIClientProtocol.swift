import Foundation

// ╔══════════════════════════════════════════════════════════╗
// ║  A1. API CLIENT — ASYNC/AWAIT                             ║
// ╚══════════════════════════════════════════════════════════╝

protocol AsyncAPIClientProtocol: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func requestRaw(_ endpoint: Endpoint) async throws -> Data
}
