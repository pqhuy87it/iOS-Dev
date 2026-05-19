
import SwiftUI

struct StockImageModel: Identifiable {
	var id = UUID()
	var name: String
	var image: UIImage?

	init(name: String) {
		self.name = name
	}
}
