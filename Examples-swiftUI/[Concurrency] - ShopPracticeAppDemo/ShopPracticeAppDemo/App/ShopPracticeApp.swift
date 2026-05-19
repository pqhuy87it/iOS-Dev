import SwiftUI
import SwiftData

/// App entry point — wires the 3 architectural layers together.
///
/// - Layer 1 (State):       `@Observable` stores injected via `.environment(_:)`
/// - Layer 2 (Events):      `AppEventBus` (Combine Subjects) injected via `.environment(_:)`
/// - Layer 3 (Persistence): SwiftData models injected via `.modelContainer(for:)`
@main
struct ShopPracticeApp: App {

    // Layer 1 — state stores owned at App level so they survive view lifecycle
    @State private var session = UserSession()
    @State private var catalog = ProductCatalog()

    // Layer 2 — event bus, same lifetime as the app
    @State private var bus = AppEventBus()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(session)
                .environment(catalog)
                .environment(bus)
        }
        // Layer 3 — SwiftData container, auto-injects \.modelContext to all views
        .modelContainer(for: [CartItem.self, Order.self])
    }
}
