import Foundation

protocol CredentialsStoring {
    func save(username: String, password: String)
    func load() -> (username: String, password: String)?
    func clear()
}

final class CredentialsStore: CredentialsStoring {
    private let usernameKey = "saved.username"
    private let passwordKey = "saved.password"
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func save(username: String, password: String) {
        defaults.set(username, forKey: usernameKey)
        defaults.set(password, forKey: passwordKey)
        defaults.synchronize()
    }
    
    func load() -> (username: String, password: String)? {
        guard let u = defaults.string(forKey: usernameKey),
              let p = defaults.string(forKey: passwordKey) else { return nil }
        return (u, p)
    }
    
    func clear() {
        defaults.removeObject(forKey: usernameKey)
        defaults.removeObject(forKey: passwordKey)
    }
}
