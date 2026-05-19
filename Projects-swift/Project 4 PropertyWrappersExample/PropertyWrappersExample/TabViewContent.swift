//
//  TabViewContent.swift
//  PropertyWrappersExample
//
//  Created by mybkhn on 2021/03/01.
//

import SwiftUI

struct TabViewContent: View {

	@State var selectedIndex = 0

	@ObservedObject var tabModel: TabModel

	var items:[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]

    var body: some View {
		VStack {
			Picker(selection: $selectedIndex, label: Text("Range:")) {
				ForEach(0 ..< self.items.count) {
					Text(self.items[$0])
				}
			}
			.pickerStyle(SegmentedPickerStyle())
			.padding()

			PageView([
				StockImageView(stockModel: self.tabModel.stockModels[0]),
				StockImageView(stockModel: self.tabModel.stockModels[1]),
				StockImageView(stockModel: self.tabModel.stockModels[2]),
				StockImageView(stockModel: self.tabModel.stockModels[3]),
				StockImageView(stockModel: self.tabModel.stockModels[4]),
				StockImageView(stockModel: self.tabModel.stockModels[5]),
				StockImageView(stockModel: self.tabModel.stockModels[6]),
				StockImageView(stockModel: self.tabModel.stockModels[7]),
				StockImageView(stockModel: self.tabModel.stockModels[8]),
				StockImageView(stockModel: self.tabModel.stockModels[9]),
				StockImageView(stockModel: self.tabModel.stockModels[10])
			], currentTab: $selectedIndex)
		}
    }
}

struct TabViewContent_Previews: PreviewProvider {
    static var previews: some View {
		TabViewContent(tabModel: TabModel(name: ""))
    }
}
