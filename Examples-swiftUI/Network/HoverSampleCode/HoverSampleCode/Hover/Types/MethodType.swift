import Foundation

public enum MethodType: Equatable {
    case get
    case post
    case put
    case delete
    case patch
    public var methodName: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        case .patch:
            return "PATCH"
        case .delete:
            return "DELETE"
        }
    }
}
