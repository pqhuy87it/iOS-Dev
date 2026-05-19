//
//  RootView.swift
//  NavigationStackExample
//
//  Created by mybkhn on 2021/04/02.
//

import SwiftUI

struct RootView: View {
	let navigationStack: NavigationStack

	var body: some View {
		NavigationView {
//			NavigationStackView(navigationStack: navigationStack) {
//				LoginScreen(navigationStack: navigationStack, router: MyRouter(navStack: navigationStack))
//					.navigationBarTitle("Login", displayMode: .inline)
//			}
			NavigationStackView(rootView: {
				LoginScreen(navigationStack: navigationStack, router: MyRouter(navStack: navigationStack))
					.navigationBarTitle("Login", displayMode: .inline)
			})
		}
		.navigationViewStyle(StackNavigationViewStyle())
	}
}
