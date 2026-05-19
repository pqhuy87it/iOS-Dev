//
//  ContentView2.swift
//  TestPopRootView
//
//  Created by mybkhn on 2021/04/18.
//

import SwiftUI

struct ContentView2: View {
	@Binding var rootIsActive : Bool

	@State var isActive : Bool = false

	var body: some View {
		VStack {
			NavigationLink(destination: createContentViewThree()) {
				Text("Hello, World #2!")
			}
			.isDetailLink(false)

			NavigationLink(destination: createContentViewTwoDotOne(),
						   isActive: self.$isActive) {
				Button {
					self.isActive = true
				} label: {
					Text("Hello, World #2.1!")
				}
			}
			.isDetailLink(false)
		}
		.navigationBarTitle("Two")
		.navigationBarBackButtonHidden(true)
	}

	// MARK: - Build Views

	func createContentViewTwoDotOne() -> some View {
		return ContentView2_1(rootIsActive: self.$isActive)
			.navigationBarTitle("Two.One")
	}

	func createContentViewThree() -> some View {
		return ContentView3(shouldPopToRootView: self.$rootIsActive)
			.navigationBarTitle("Three")
	}
}
