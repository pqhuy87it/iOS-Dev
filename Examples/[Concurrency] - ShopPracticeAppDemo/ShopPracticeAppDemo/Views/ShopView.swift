import SwiftUI
import SwiftData
import Combine

struct ShopView: View {
    // Layer 1
    @Environment(ProductCatalog.self) private var catalog
    // Layer 2
    @Environment(AppEventBus.self) private var bus
    // Layer 3
    @Environment(\.modelContext) private var ctx
    @Query private var cartItems: [CartItem]

    var body: some View {
        NavigationStack {
            List(catalog.products) { product in
                HStack(spacing: 14) {
                    Text(product.emoji).font(.system(size: 36))

                    VStack(alignment: .leading) {
                        Text(product.name).font(.headline)
                        Text(product.price, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        addToCart(product)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Shop")
            .refreshable { await catalog.refresh() }
            .overlay {
                if catalog.isLoading && catalog.products.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private func addToCart(_ product: Product) {
        // Layer 3 — increment if already in cart, otherwise insert
        if let existing = cartItems.first(where: { $0.productId == product.id }) {
            existing.quantity += 1
        } else {
            ctx.insert(CartItem(product: product))
        }

        // Layer 2 — fire a one-shot UI event
        bus.showToast.send(ToastMessage(
            text: "Added \(product.name)",
            style: .success
        ))
    }
}
