//
//  ContentView.swift
//  Bottom sheet in SwiftUI
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct ContentView: View {
	@State private var bottomSheetShown = false
	
	var body: some View {
		GeometryReader { geometry in
			Color.green
			BottomSheetView(
				isOpen: self.$bottomSheetShown,
				maxHeight: geometry.size.height * 0.7
			) {
				Color.blue
			}
		}.edgesIgnoringSafeArea(.all)
	}
}
