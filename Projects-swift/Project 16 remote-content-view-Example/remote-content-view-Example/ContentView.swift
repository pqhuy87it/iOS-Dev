//
//  ContentView.swift
//  remote-content-view-Example
//
//  Created by mybkhn on 2021/05/31.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
		NavigationView {
			List {
				NavigationLink(
					destination: ImageView(),
					label: {
						Text("Image View")
					})

				NavigationLink(
					destination: PostsView(),
					label: {
						Text("Posts View")
					})
			}
		}
		.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
