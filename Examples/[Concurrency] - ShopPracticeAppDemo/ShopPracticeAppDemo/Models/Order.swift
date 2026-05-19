import Foundation
import SwiftData

/// Persistent completed order.
/// **Layer 3 — SwiftData.**
@Model
final class Order {
    @Attribute(.unique) var id: String
    var orderNumber: String
    var total: Double
    var itemCount: Int
    var summary: String   // pre-rendered like "2× Coffee, 1× Pizza Slice"
    var placedAt: Date

    init(orderNumber: String, total: Double, itemCount: Int, summary: String) {
        self.id = UUID().uuidString
        self.orderNumber = orderNumber
        self.total = total
        self.itemCount = itemCount
        self.summary = summary
        self.placedAt = .now
    }
}
