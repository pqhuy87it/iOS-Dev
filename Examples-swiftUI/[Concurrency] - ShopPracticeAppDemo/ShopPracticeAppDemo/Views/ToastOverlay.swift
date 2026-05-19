import SwiftUI

/// Global toast overlay — listens to `bus.showToast` and displays messages
/// at the top of whatever view this modifier is attached to.
///
/// Demonstrates how event-driven UI integrates cleanly with the view hierarchy:
/// any module in the app can `bus.showToast.send(...)` and the toast will
/// appear without that module having any reference to the UI layer.
struct ToastOverlayModifier: ViewModifier {
    @Environment(AppEventBus.self) private var bus
    @State private var currentToast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = currentToast {
                    ToastBanner(message: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                        .zIndex(1000)
                }
            }
            .animation(.spring(duration: 0.35), value: currentToast)
            .onReceive(bus.showToast) { message in
                currentToast = message
                // Auto-dismiss after 2s, but only if THIS message is still showing
                // (otherwise a quick second toast would be cut short).
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if currentToast?.id == message.id {
                        currentToast = nil
                    }
                }
            }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}

private struct ToastBanner: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
            Text(message.text).font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: .capsule)
        .foregroundStyle(color)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }

    private var iconName: String {
        switch message.style {
        case .info:    "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .error:   "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch message.style {
        case .info:    .blue
        case .success: .green
        case .error:   .red
        }
    }
}
