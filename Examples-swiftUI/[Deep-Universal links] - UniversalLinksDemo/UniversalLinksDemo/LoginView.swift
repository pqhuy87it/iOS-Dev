import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var registrationStore: RegistrationStore
    
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Welcome")
                    .font(.largeTitle.bold())
                
                VStack(spacing: 12) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                
                Button {
                    // Mock login
                } label: {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Create new user") {
                    registrationStore.reset()
                    registrationStore.advance(to: .step1Account)
                    appState.route = .registration
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Login")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
