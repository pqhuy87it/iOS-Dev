import Foundation
import Observation

/// Authentication state — in-memory, owned at App level.
/// **Layer 1 — `@Observable` store.**
@Observable
final class UserSession {
    enum State {
        case loggedOut
        case loggedIn(username: String)
    }

    private(set) var state: State = .loggedOut

    var isLoggedIn: Bool {
        if case .loggedIn = state { return true }
        return false
    }

    var username: String? {
        if case .loggedIn(let name) = state { return name }
        return nil
    }

    func login(as username: String) {
        state = .loggedIn(username: username)
    }

    func logout() {
        state = .loggedOut
    }
}
