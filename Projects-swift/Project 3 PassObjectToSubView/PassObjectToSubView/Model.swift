//
//  Model.swift
//  PassObjectToSubView
//
//  Created by mybkhn on 2021/03/01.
//

import SwiftUI

class Model: ObservableObject {
	@Published var items = [Item]()

	init(titles: [String]) {
		items = titles.map({ Item(title: $0) })
	}

	func updateTitle(for item: Item, to newTitle: String) {
		if let index = items.firstIndex(where: { $0.id == item.id }) {
			items[index].title = newTitle
		}

	}
}
