//
//  ContentView.swift
//  LoadingView
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
		LoadingView(isShowing: .constant(true)) {
			NavigationView {
				List(["1", "2", "3", "4", "5"], id: \.self) { row in
					Text(row)
				}.navigationBarTitle(Text("A List"), displayMode: .large)
			}
		}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
