import SwiftUI
import SwiftData
import Combine

struct CartView: View {
    // Layer 2
    @Environment(AppEventBus.self) private var bus
    // Layer 3
    @Environment(\.modelContext) private var ctx
    @Query(sort: \CartItem.addedAt) private var items: [CartItem]

    private var total: Double {
        items.reduce(0) { $0 + $1.subtotal }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Cart is empty",
                        systemImage: "cart",
                        description: Text("Add items from the Shop tab")
                    )
                } else {
                    List {
                        Section {
                            ForEach(items) { item in
                                CartRow(item: item)
                            }
                            .onDelete(perform: deleteItems)
                        }
                        Section {
                            HStack {
                                Text("Total").bold()
                                Spacer()
                                Text(total, format: .currency(code: "USD")).bold()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cart")
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Checkout", action: checkout)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets { ctx.delete(items[index]) }
    }

    /// Checkout demonstrates all 3 layers in one flow:
    ///   1. Persist the order (SwiftData)
    ///   2. Clear cart items (SwiftData)
    ///   3. Fire purchaseCompleted + toast events (AppEventBus)
    ///
    /// Cart badge and Orders badge in `RootTabView` will update automatically
    /// because they use `@Query`. The Orders tab will also highlight the new
    /// order because it subscribes to `bus.purchaseCompleted`.
    private func checkout() {
        let summary = items
            .map { "\($0.quantity)× \($0.productName)" }
            .joined(separator: ", ")
        let itemCount = items.reduce(0) { $0 + $1.quantity }
        let orderNumber = "#\(Int.random(in: 1000...9999))"

        // (1) Persist the order
        let order = Order(
            orderNumber: orderNumber,
            total: total,
            itemCount: itemCount,
            summary: summary
        )
        ctx.insert(order)

        // (2) Clear cart
        for item in items { ctx.delete(item) }

        // (3) Fire events — purchase complete + toast
        bus.purchaseCompleted.send(OrderEvent(
            orderId: order.id,
            orderNumber: order.orderNumber,
            total: order.total
        ))
        bus.showToast.send(ToastMessage(
            text: "Order placed: \(orderNumber)",
            style: .success
        ))
    }
}

private struct CartRow: View {
    let item: CartItem

    var body: some View {
        HStack {
            Text(item.productEmoji).font(.title)
            VStack(alignment: .leading) {
                Text(item.productName)
                Text("\(item.quantity) × \(item.price, format: .currency(code: "USD"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(item.subtotal, format: .currency(code: "USD")).bold()
        }
    }
}
