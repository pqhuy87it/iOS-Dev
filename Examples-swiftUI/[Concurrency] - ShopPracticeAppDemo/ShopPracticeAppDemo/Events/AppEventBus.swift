import Foundation
import Combine
import Observation

/// Typed event bus — type-safe replacement for `NotificationCenter`.
/// **Layer 2 — one-shot signals between unrelated parts of the app.**
///
/// Why `@Observable`: required so it can be injected via `.environment(_:)`.
/// Why `@ObservationIgnored`: `PassthroughSubject` is a *channel*, not observable state;
/// subscribers should listen via `.onReceive(_:)`, not via property observation.
@Observable
final class AppEventBus {

    /// Fired after a purchase is successfully placed.
    @ObservationIgnored
    let purchaseCompleted = PassthroughSubject<OrderEvent, Never>()

    /// Fired when the user logs out — listeners typically clear local state.
    @ObservationIgnored
    let userLoggedOut = PassthroughSubject<Void, Never>()

    /// Show a global toast at the top of the screen.
    @ObservationIgnored
    let showToast = PassthroughSubject<ToastMessage, Never>()
}

/// Payload for the purchase event.
///
/// Kept as a plain struct (not the SwiftData `Order` model) so consumers of the
/// event don't get coupled to the persistence layer. This is a small but
/// important architectural detail — events should travel in plain value types.
struct OrderEvent {
    let orderId: String
    let orderNumber: String
    let total: Double
}

/// Payload for the toast event.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: Style

    enum Style { case info, success, error }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}
