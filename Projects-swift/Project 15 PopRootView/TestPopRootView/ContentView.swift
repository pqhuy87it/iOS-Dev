//
//  ContentView.swift
//  TestPopRootView
//
//  Created by mybkhn on 2021/04/18.
//

import SwiftUI

struct ContentView: View {
	@State var isActive : Bool = false

	var body: some View {
		NavigationView {
			NavigationLink(
				destination: ContentView2(rootIsActive: self.$isActive),
				isActive: self.$isActive
			) {
				Text("Hello, World!")
			}
			.isDetailLink(false)
			.navigationBarTitle(Text("Root"), displayMode: .inline)
		}
		.navigationBarBackButtonHidden(true)
		.navigationViewStyle(StackNavigationViewStyle())
	}
}
