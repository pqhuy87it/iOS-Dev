//
//  ContentView.swift
//  TabbedViewTutorial
//
//  Created by Duy Bui on 10/25/19.
//  Copyright © 2019 Duy Bui. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	init() {
		setupTabBar()
	}

    var body: some View {
        TabView {
           RedView()
             .tabItem {
                Image(systemName: "phone.fill")
                Text("First Tab")
              }

           BlueView()
             .tabItem {
                Image(systemName: "tv.fill")
                Text("Second Tab")
              }
        }
    }
}

//MARK: - Tab bar view appearance
extension ContentView {
	func setupTabBar() {
//		UITabBar.appearance().barTintColor = .white
		UITabBar.appearance().tintColor = .blue
		UITabBar.appearance().layer.borderColor = UIColor.clear.cgColor
		UITabBar.appearance().clipsToBounds = true
		UITabBarItem.appearance().setTitleTextAttributes([
			NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20),

		], for: .normal)
	}
}

struct RedView: View {
    var body: some View {
        Color.red
    }
}

struct BlueView: View {
    var body: some View {
        Color.blue
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
