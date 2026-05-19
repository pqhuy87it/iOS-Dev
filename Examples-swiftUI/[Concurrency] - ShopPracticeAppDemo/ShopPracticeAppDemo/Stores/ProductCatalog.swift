import Foundation
import Observation

/// Product catalog — represents available products.
/// In a real app, this is fetched from a backend API.
/// **Layer 1 — `@Observable` store.**
@Observable
final class ProductCatalog {
    private(set) var products: [Product]
    private(set) var isLoading = false

    init(products: [Product] = Product.samples) {
        self.products = products
    }

    /// Simulate an API refresh.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(for: .seconds(0.6))
        // Real app: products = try await api.fetchProducts()
        products = Product.samples
    }

    func product(id: String) -> Product? {
        products.first { $0.id == id }
    }
}
