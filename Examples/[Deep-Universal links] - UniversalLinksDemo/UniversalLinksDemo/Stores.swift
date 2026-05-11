import Foundation
import Combine

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
    private let defaults = UserDefaults.standard
    
    init() {
        // Load draft
        if let data = UserDefaults.standard.data(forKey: "registration.draft"),
           let saved = try? JSONDecoder().decode(RegistrationDraft.self, from: data) {
            self.draft = saved
        } else {
            self.draft = RegistrationDraft()
        }
        
        // Load step
        let raw = UserDefaults.standard.integer(forKey: "registration.step")
        self.currentStep = RegistrationStep(rawValue: raw) ?? .notStarted
    }
    
    // MARK: Public API
    
    func advance(to step: RegistrationStep) {
        currentStep = step
    }
    
    func reset() {
        draft = RegistrationDraft()
        currentStep = .notStarted
        defaults.removeObject(forKey: draftKey)
        defaults.removeObject(forKey: stepKey)
    }
    
    // MARK: Persistence
    
    private func persistDraft() {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: draftKey)
    }
    
    private func persistStep() {
        defaults.set(currentStep.rawValue, forKey: stepKey)
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
