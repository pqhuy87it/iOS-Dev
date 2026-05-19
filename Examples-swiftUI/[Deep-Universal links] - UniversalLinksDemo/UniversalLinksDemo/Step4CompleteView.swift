import SwiftUI

struct Step4CompleteView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Register Complete!")
                .font(.largeTitle.bold())
            
            VStack(spacing: 8) {
                infoRow(label: "Username",  value: registrationStore.draft.username)
                infoRow(label: "Full Name",
                        value: "\(registrationStore.draft.firstName) \(registrationStore.draft.lastName)")
                infoRow(label: "Email",     value: registrationStore.draft.email)
                infoRow(label: "Active Token",
                        value: registrationStore.draft.activeToken ?? "-")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            Button("Go to Login") {
                registrationStore.reset()
                appState.route = .login
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
