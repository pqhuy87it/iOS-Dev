import Foundation
import SwiftData

/// Persistent cart item — survives app restarts.
/// **Layer 3 — SwiftData.**
@Model
final class CartItem {
    @Attribute(.unique) var id: String
    var productId: String
    var productName: String
    var productEmoji: String
    var price: Double
    var quantity: Int
    var addedAt: Date

    init(product: Product, quantity: Int = 1) {
        self.id = UUID().uuidString
        self.productId = product.id
        self.productName = product.name
        self.productEmoji = product.emoji
        self.price = product.price
        self.quantity = quantity
        self.addedAt = .now
    }

    var subtotal: Double { price * Double(quantity) }
}
