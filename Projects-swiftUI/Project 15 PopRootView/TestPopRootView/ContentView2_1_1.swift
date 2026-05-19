//
//  ContentView2_1_1.swift
//  TestPopRootView
//
//  Created by mybkhn on 2021/04/18.
//

import SwiftUI

struct ContentView2_1_1: View {
	@Binding var shouldPopToRootView : Bool

	var body: some View {
		VStack {
			Button {
				self.shouldPopToRootView = false
			} label: {
				Text("Back to view 2!")
			}
		}
		.navigationBarBackButtonHidden(true)
	}
}
