
import SwiftUI

class StockModel: ObservableObject {
	var name: String

	@Published var stockImage = StockImageModel(name: "")

	init(name: String) {
		self.name = name
	}
}
