import Foundation

/// Domain model — a product available in the shop.
/// Not persisted (in a real app this would come from a backend API).
struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let price: Double
    let emoji: String
}

extension Product {
    /// Sample catalog for practice — replace with API call in real app.
    static let samples: [Product] = [
        Product(id: "p1", name: "Coffee",      price: 4.5, emoji: "☕️"),
        Product(id: "p2", name: "Croissant",   price: 3.0, emoji: "🥐"),
        Product(id: "p3", name: "Sandwich",    price: 8.5, emoji: "🥪"),
        Product(id: "p4", name: "Pizza Slice", price: 6.0, emoji: "🍕"),
        Product(id: "p5", name: "Salad",       price: 9.5, emoji: "🥗"),
        Product(id: "p6", name: "Smoothie",    price: 5.5, emoji: "🥤"),
    ]
}
