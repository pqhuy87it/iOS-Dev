//
//  SubView.swift
//  PassObjectToSubView
//
//  Created by mybkhn on 2021/03/01.
//

import SwiftUI

struct SubView: View {
	var item: Item
	@EnvironmentObject var model: Model
	@State private var textFieldContents = ""

	var body: some View {
		Form {
			TextField("Title", text: $textFieldContents, onEditingChanged: { _ in
				self.model.updateTitle(for: self.item, to: self.textFieldContents)
			})
		}
		.onAppear(perform: loadItemText)
	}

	func loadItemText() {
		textFieldContents = item.title
	}

}
