import Foundation
@testable import SwiftUI_MVVM_Demo

final class MockAPIService: APIServiceType {
    // Lưu trữ Result thay vì Closure để tránh lỗi ép kiểu Any của Swift
    var stubs: [String: Any] = [:]
    
    // Setup bằng Result
    func stub<Request: APIRequestType>(for type: Request.Type, response: Result<Request.Response, Error>) {
        let key = String(describing: type)
        stubs[key] = response
    }
    
    func response<Request: APIRequestType>(from request: Request) async throws -> Request.Response {
        let key = String(describing: Request.self)
        
        // ⏳ BẮT BUỘC: Thêm delay cực nhỏ (10ms) để nhường luồng (Yield thread).
        // Giúp XCTest có thời gian đăng ký Expectation, ngăn chặn Race Condition.
        try await Task.sleep(nanoseconds: 10_000_000)
        
        // Trả về dữ liệu nếu đã được setup
        if let result = stubs[key] as? Result<Request.Response, Error> {
            switch result {
            case .success(let res): return res
            case .failure(let err): throw err
            }
        }
        
        // 🛡 FALLBACK AN TOÀN: Nếu quên setup stub (hoặc đối với các test không quan tâm API như test Tracker),
        // nó sẽ tự động trả về một mảng rỗng thay vì văng fatalError làm crash Test Suite.
        if let defaultMock = SearchRepositoryResponse(items: []) as? Request.Response {
            return defaultMock
        }
        
        fatalError("🚨 Chưa setup stub cho \(key)")
    }
}
