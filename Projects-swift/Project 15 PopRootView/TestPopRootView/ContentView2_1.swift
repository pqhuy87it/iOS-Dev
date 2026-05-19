//
//  ContentView2_1.swift
//  TestPopRootView
//
//  Created by mybkhn on 2021/04/18.
//

import SwiftUI

struct ContentView2_1: View {
	@Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

	@Binding var rootIsActive : Bool
	@State var isActive : Bool = false

    var body: some View {
		VStack {
			Button {
				self.presentationMode.wrappedValue.dismiss()
			} label: {
				Text("Back to previous!")
			}

			NavigationLink(destination: ContentView2_1_1(shouldPopToRootView: self.$rootIsActive),
						   isActive: self.$isActive) {
				Button {
					self.isActive = true
				} label: {
					Text("Hello, World #2.1.1!")
				}

			}
			.isDetailLink(false)
			.navigationBarTitle("Two.One.one")
		}
		.navigationBarBackButtonHidden(true)
    }
}

