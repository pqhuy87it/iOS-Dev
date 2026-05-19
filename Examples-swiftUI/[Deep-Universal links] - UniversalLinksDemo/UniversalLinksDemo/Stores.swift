import Foundation
import Combine
import CryptoKit
import Security

// MARK: - Keychain Helper

private enum Keychain {

    static func save(_ data: Data, forKey key: String) {
        let account = sha256(key)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      account,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> Data? {
        let account = sha256(key)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(forKey key: String) {
        let account = sha256(key)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - RegistrationStore

final class RegistrationStore: ObservableObject {

    @Published var draft: RegistrationDraft {
        didSet { persistDraft() }
    }

    @Published var currentStep: RegistrationStep {
        didSet { persistStep() }
    }

    private let draftKey = "registration.draft"
    private let stepKey  = "registration.step"

    init() {
        if let data = Keychain.load(forKey: "registration.draft"),
           let saved = try? JSONDecoder().decode(RegistrationDraft.self, from: data) {
            self.draft = saved
        } else {
            self.draft = RegistrationDraft()
        }

        if let data = Keychain.load(forKey: "registration.step"),
           let raw = try? JSONDecoder().decode(Int.self, from: data) {
            self.currentStep = RegistrationStep(rawValue: raw) ?? .notStarted
        } else {
            self.currentStep = .notStarted
        }
    }

    // MARK: Public API

    func advance(to step: RegistrationStep) {
        currentStep = step
    }

    func reset() {
        draft = RegistrationDraft()
        currentStep = .notStarted
        Keychain.delete(forKey: draftKey)
        Keychain.delete(forKey: stepKey)
    }

    // MARK: Persistence

    private func persistDraft() {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        Keychain.save(data, forKey: draftKey)
    }

    private func persistStep() {
        guard let data = try? JSONEncoder().encode(currentStep.rawValue) else { return }
        Keychain.save(data, forKey: stepKey)
    }
}

// MARK: - AppState

final class AppState: ObservableObject {
    @Published var route: AppRoute = .login
}

// MARK: - DeepLinkCoordinator

final class DeepLinkCoordinator: ObservableObject {
    
    enum DeepLink {
        case activate(token: String)
    }
    
    /// Queue link nếu app chưa ready (cold start)
    private var pendingLink: DeepLink?
    private var isAppReady = false
    
    private weak var registrationStore: RegistrationStore?
    private weak var appState: AppState?
    
    func configure(store: RegistrationStore, appState: AppState) {
        self.registrationStore = store
        self.appState = appState
    }
    
    func appDidBecomeReady() {
        isAppReady = true
        if let pending = pendingLink {
            pendingLink = nil
            route(pending)
        }
    }
    
    func handle(_ url: URL) {
        guard let link = parse(url) else {
            print("⚠️ DeepLink không nhận diện được: \(url)")
            return
        }
        
        if isAppReady {
            route(link)
        } else {
            // Cold start — chưa setup xong UI, queue lại
            pendingLink = link
        }
    }
    
    // MARK: Private
    
    private func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "myapp" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        // myapp://register?active_token=123456
        if components.host == "register",
           let token = components.queryItems?
                .first(where: { $0.name == "active_token" })?.value,
           !token.isEmpty {
            return .activate(token: token)
        }
        
        return nil
    }
    
    private func route(_ link: DeepLink) {
        switch link {
        case .activate(let token):
            guard let store = registrationStore, let appState = appState else { return }
            store.draft.activeToken = token
            store.advance(to: .step4Complete)
            appState.route = .registration
        }
    }
}
