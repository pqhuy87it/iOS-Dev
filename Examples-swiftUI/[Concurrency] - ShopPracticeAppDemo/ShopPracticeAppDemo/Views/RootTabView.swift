import SwiftUI
import SwiftData

/// Top-level tab container.
///
/// Notice that tab badges are driven by `@Query` directly — no manual sync needed.
/// When any tab inserts/deletes a `CartItem` or `Order` in the shared
/// `ModelContext`, this view re-evaluates and updates the badges automatically.
struct RootTabView: View {
    @Query private var cartItems: [CartItem]
    @Query(sort: \Order.placedAt, order: .reverse) private var orders: [Order]

    private var cartCount: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        TabView {
            ShopView()
                .tabItem { Label("Shop", systemImage: "bag") }

            CartView()
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(cartCount)

            OrdersView()
                .tabItem { Label("Orders", systemImage: "shippingbox") }
                .badge(orders.count)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        // Global toast overlay listens to `bus.showToast` from any tab.
        .withToastOverlay()
    }
}
