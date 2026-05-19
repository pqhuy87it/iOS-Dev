import SwiftUI
import Combine


// ╔══════════════════════════════════════════════════════════╗
// ║  SHARED: MODELS & ERRORS & ENDPOINT CONFIG               ║
// ╚══════════════════════════════════════════════════════════╝

// === API Models ===

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let email: String
    let avatar: String?
}
