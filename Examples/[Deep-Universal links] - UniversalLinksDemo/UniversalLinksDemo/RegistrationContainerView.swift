import SwiftUI

struct RegistrationContainerView: View {
    @EnvironmentObject var registrationStore: RegistrationStore
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepIndicator(currentStep: registrationStore.currentStep)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                Divider()
                
                Group {
                    switch registrationStore.currentStep {
                    case .notStarted, .step1Account:
                        Step1AccountView()
                    case .step2PersonalInfo:
                        Step2PersonalInfoView()
                    case .step3Email:
                        Step3EmailView()
                    case .step4Complete:
                        Step4CompleteView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if registrationStore.currentStep != .step4Complete {
                        Button("Cancel") {
                            registrationStore.reset()
                            appState.route = .login
                        }
                    }
                }
            }
        }
    }
}
