import Foundation

public enum AuthProviderType {
    case bearer(token: String)
    case basic(username: String, password: String)
    case none
}
