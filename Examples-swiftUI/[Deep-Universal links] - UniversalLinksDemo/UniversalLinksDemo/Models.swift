import Foundation

// MARK: - Step

enum RegistrationStep: Int, Codable, CaseIterable {
    case notStarted = 0
    case step1Account = 1
    case step2PersonalInfo = 2
    case step3Email = 3
    case step4Complete = 4
    
    var title: String {
        switch self {
        case .notStarted:        return ""
        case .step1Account:      return "Account"
        case .step2PersonalInfo: return "Personal"
        case .step3Email:        return "Email"
        case .step4Complete:     return "Done"
        }
    }
}

// MARK: - Draft

struct RegistrationDraft: Codable, Equatable {
    // Step 1
    var username: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    
    // Step 2
    var firstName: String = ""
    var lastName: String = ""
    var address: String = ""
    var phoneNumber: String = ""
    
    // Step 3
    var email: String = ""
    
    // Step 4 (từ deep link)
    var activeToken: String?
}

// MARK: - App Route

enum AppRoute {
    case login
    case registration
}
