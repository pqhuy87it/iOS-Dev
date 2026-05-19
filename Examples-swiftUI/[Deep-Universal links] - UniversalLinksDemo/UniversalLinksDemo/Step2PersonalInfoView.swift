import SwiftUI

struct Step2PersonalInfoView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    
    var body: some View {
        Form {
            Section("Personal Info") {
                TextField("First Name", text: $registrationStore.draft.firstName)
                TextField("Last Name",  text: $registrationStore.draft.lastName)
                TextField("Address",    text: $registrationStore.draft.address,
                          axis: .vertical)
                    .lineLimit(2...4)
                TextField("Phone Number", text: $registrationStore.draft.phoneNumber)
                    .keyboardType(.phonePad)
            }
            
            Section {
                HStack {
                    Button("Back") {
                        registrationStore.advance(to: .step1Account)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Next") {
                        registrationStore.advance(to: .step3Email)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        let d = registrationStore.draft
        return !d.firstName.isEmpty
            && !d.lastName.isEmpty
            && !d.phoneNumber.isEmpty
    }
}
