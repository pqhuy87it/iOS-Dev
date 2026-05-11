import SwiftUI

struct Step1AccountView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    
    var body: some View {
        Form {
            Section("Account Info") {
                TextField("Username", text: $registrationStore.draft.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                SecureField("Password", text: $registrationStore.draft.password)
                
                SecureField("Confirm Password",
                            text: $registrationStore.draft.confirmPassword)
            }
            
            if let error = validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Section {
                Button("Next") {
                    registrationStore.advance(to: .step2PersonalInfo)
                }
                .frame(maxWidth: .infinity)
                .disabled(validationError != nil)
            }
        }
    }
    
    private var validationError: String? {
        let d = registrationStore.draft
        if d.username.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Username is required"
        }
        if d.password.count < 6 {
            return "Password must be at least 6 characters"
        }
        if d.password != d.confirmPassword {
            return "Passwords do not match"
        }
        return nil
    }
}
