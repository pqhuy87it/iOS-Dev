import SwiftUI

struct StepIndicator: View {
    let currentStep: RegistrationStep
    
    private let steps: [RegistrationStep] = [
        .step1Account, .step2PersonalInfo, .step3Email, .step4Complete
    ]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepCircle(index: index, step: step)
                
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(isCompleted(steps[index + 1]) ? Color.accentColor
                                                            : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }
    
    private func stepCircle(index: Int, step: RegistrationStep) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCompleted(step) ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                if step.rawValue < currentStep.rawValue {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(isCompleted(step) ? .white : .secondary)
                }
            }
            
            Text(step.title)
                .font(.caption2)
                .foregroundColor(isCompleted(step) ? .primary : .secondary)
        }
    }
    
    private func isCompleted(_ step: RegistrationStep) -> Bool {
        step.rawValue <= currentStep.rawValue
    }
}
