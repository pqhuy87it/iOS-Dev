import Foundation

protocol APIServiceType {
    func response<Request: APIRequestType>(from request: Request) async throws -> Request.Response
}
