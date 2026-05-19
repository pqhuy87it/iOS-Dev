import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Đăng nhập")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("login.title")
                
                TextField("Username", text: $viewModel.username)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("login.username.textField")
                
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("login.password.secureField")
                
                Toggle("Ghi nhớ đăng nhập", isOn: $viewModel.rememberMe)
                    .accessibilityIdentifier("login.rememberMe.toggle")
                    .accessibilityValue(viewModel.rememberMe ? "1" : "0")
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .accessibilityIdentifier("login.error.label")
                }
                
                Button {
                    Task { await viewModel.login() }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .accessibilityIdentifier("login.loading.indicator")
                        }
                        Text("Đăng nhập")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isLoginEnabled ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!viewModel.isLoginEnabled)
                .accessibilityIdentifier("login.submit.button")
                
                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $viewModel.isLoggedIn) {
                HomeView(username: viewModel.username)
            }
        }
    }
}
