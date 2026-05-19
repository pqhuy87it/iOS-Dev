import SwiftUI
import SwiftData
import Combine

struct ProfileView: View {
    @Environment(UserSession.self) private var session
    @Environment(AppEventBus.self) private var bus
    @Environment(\.modelContext) private var ctx
    @Query private var cartItems: [CartItem]
    @Query private var orders: [Order]

    @State private var usernameInput = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let username = session.username {
                        LabeledContent("Signed in as", value: username)
                        Button("Logout", role: .destructive, action: logout)
                    } else {
                        TextField("Username", text: $usernameInput)
                            .textInputAutocapitalization(.never)
                        Button("Login") { login() }
                            .disabled(usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Stats") {
                    LabeledContent("Cart items", value: "\(cartItems.count)")
                    LabeledContent("Total orders", value: "\(orders.count)")
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func login() {
        let name = usernameInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        session.login(as: name)
        bus.showToast.send(ToastMessage(text: "Welcome, \(name)!", style: .info))
        usernameInput = ""
    }

    /// Logout demonstrates a cross-cutting action:
    ///   - Clear cart in SwiftData (business rule: cart is per-session)
    ///   - Update auth state (UserSession @Observable)
    ///   - Broadcast logout event so any other interested module can react
    ///   - Show toast feedback
    private func logout() {
        for item in cartItems { ctx.delete(item) }
        session.logout()
        bus.userLoggedOut.send(())
        bus.showToast.send(ToastMessage(text: "Logged out", style: .info))
    }
}
