
import SwiftUI

class TabModel: ObservableObject {
	var name: String

	@Published var stockModels: [StockModel] = [
		StockModel(name: "1"),
		StockModel(name: "2"),
		StockModel(name: "3"),
		StockModel(name: "4"),
		StockModel(name: "5"),
		StockModel(name: "6"),
		StockModel(name: "7"),
		StockModel(name: "8"),
		StockModel(name: "9"),
		StockModel(name: "10"),
		StockModel(name: "11")
	]

	init(name: String) {
		self.name = name
	}
}

