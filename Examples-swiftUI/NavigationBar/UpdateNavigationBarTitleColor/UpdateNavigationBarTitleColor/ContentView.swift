//
//  ContentView.swift
//  UpdateNavigationBarTitleColor
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
//		NavigationView {
//			ScrollView {
//				Text("Don't use .appearance()!")
//			}
//			.navigationBarTitle("Try it!", displayMode: .inline)
//			.navigationViewStyle(StackNavigationViewStyle())
//			.background(NavigationConfigurator { nc in
//				nc.navigationBar.barTintColor = .blue
//				nc.navigationBar.tintColor = .blue
//				nc.navigationBar.backgroundColor = .blue
//				nc.navigationBar.titleTextAttributes = [.foregroundColor : UIColor.red]
//			})
//		}

		NavigationView {
			Text("Hello World")
				.navigationBarTitle("Try it!", displayMode: .inline)
				.navigationViewStyle(StackNavigationViewStyle())
				.navigationBarColor(backgroundColor: .blue, titleColor: .white) // This is how you will use it
		}

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
