import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        switch appState.route {
        case .login:
            LoginView()
        case .registration:
            RegistrationContainerView()
        }
    }
}
