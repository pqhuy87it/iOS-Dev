//
//  ContentView.swift
//  PassObjectToSubView
//
//  Created by mybkhn on 2021/03/01.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var model = Model(titles: ["Larry", "Moe", "Curly"])
	var body: some View {
		NavigationView {
			List {
				ForEach(model.items) {item in
					NavigationLink(destination: SubView(item: item).environmentObject(self.model)) {
						Text(item.title)
					}
				}
				.onDelete(perform: deleteItem)
			}
		}
	}

	func deleteItem(indexSet: IndexSet) {
		self.model.items.remove(atOffsets: indexSet)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
