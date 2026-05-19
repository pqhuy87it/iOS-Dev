//
//  ContentView3.swift
//  TestPopRootView
//
//  Created by mybkhn on 2021/04/18.
//

import SwiftUI

struct ContentView3: View {
	@Binding var shouldPopToRootView : Bool

	var body: some View {
		VStack {
			Text("Hello, World #3!")
			Button (action: { self.shouldPopToRootView = false } ){
				Text("Pop to root")
			}
		}
		.navigationBarTitle("Three")
		.navigationBarBackButtonHidden(true)
	}
}
