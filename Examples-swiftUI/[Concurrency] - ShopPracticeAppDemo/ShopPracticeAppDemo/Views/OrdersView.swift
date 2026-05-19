import SwiftUI
import SwiftData

struct OrdersView: View {
    @Environment(AppEventBus.self) private var bus
    @Query(sort: \Order.placedAt, order: .reverse) private var orders: [Order]

    /// Local UI state — which order to highlight briefly after checkout.
    @State private var highlightedOrderId: String?

    var body: some View {
        NavigationStack {
            Group {
                if orders.isEmpty {
                    ContentUnavailableView(
                        "No orders yet",
                        systemImage: "shippingbox",
                        description: Text("Your completed orders will appear here")
                    )
                } else {
                    List(orders) { order in
                        OrderRow(
                            order: order,
                            isHighlighted: order.id == highlightedOrderId
                        )
                    }
                }
            }
            .navigationTitle("Orders")
            // Layer 2 → UI: react to the event for a brief visual highlight.
            // The list itself updates via @Query without needing this subscription.
            .onReceive(bus.purchaseCompleted) { event in
                highlightedOrderId = event.orderId
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    if highlightedOrderId == event.orderId {
                        highlightedOrderId = nil
                    }
                }
            }
        }
    }
}

private struct OrderRow: View {
    let order: Order
    let isHighlighted: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.orderNumber).font(.headline)
                Text(order.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(order.placedAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(order.total, format: .currency(code: "USD")).bold()
        }
        .padding(.vertical, 4)
        .listRowBackground(
            isHighlighted ? Color.green.opacity(0.15) : Color.clear
        )
        .animation(.easeInOut, value: isHighlighted)
    }
}
