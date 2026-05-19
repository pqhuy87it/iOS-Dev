import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var rememberMe: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isLoggedIn: Bool = false
    
    private let store: CredentialsStoring
    
    init(store: CredentialsStoring? = nil) {
        self.store = store ?? CredentialsStore()
        prefillIfRemembered()
    }
    
    var isLoginEnabled: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
    
    private func prefillIfRemembered() {
        if let creds = store.load() {
            username = creds.username
            password = creds.password
            rememberMe = true
        }
    }
    
    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        // Simulate API call
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Demo logic: hardcoded valid credentials
        guard username == "admin" && password == "123456" else {
            errorMessage = "Sai username hoặc password"
            return
        }
        
        if rememberMe {
            print("--- [LoginViewModel] Saving credentials for \(username)")
            store.save(username: username, password: password)
        } else {
            print("--- [LoginViewModel] Clearing credentials because rememberMe is false")
            store.clear()
        }
        
        isLoggedIn = true
    }
}
