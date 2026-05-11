import SwiftUI

struct Step3EmailView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    
    @State private var codeSent = false
    
    var body: some View {
        Form {
            Section("Email") {
                TextField("Email", text: $registrationStore.draft.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Section {
                Button(codeSent ? "Code Sent ✓" : "Send Activation Code") {
                    sendCode()
                }
                .frame(maxWidth: .infinity)
                .disabled(!isEmailValid || codeSent)
            }
            
            if codeSent {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("📧 Đã gửi link kích hoạt tới email của bạn")
                            .font(.subheadline.bold())
                        
                        Text("Mở email và click vào link để hoàn tất đăng ký.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        Text("🧪 Test trên Simulator:")
                            .font(.caption.bold())
                        
                        Text("xcrun simctl openurl booted 'myapp://register?active_token=123456'")
                            .font(.system(.caption2, design: .monospaced))
                            .padding(8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
                            .textSelection(.enabled)
                        
                        Text("Hoặc: Kill app → mở Safari → gõ URL trên → app sẽ mở Step 4")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button("Back") {
                    registrationStore.advance(to: .step2PersonalInfo)
                }
            }
        }
    }
    
    private var isEmailValid: Bool {
        registrationStore.draft.email.contains("@") &&
        registrationStore.draft.email.contains(".")
    }
    
    private func sendCode() {
        // Mock: backend gửi email với link myapp://register?active_token=...
        codeSent = true
    }
}
