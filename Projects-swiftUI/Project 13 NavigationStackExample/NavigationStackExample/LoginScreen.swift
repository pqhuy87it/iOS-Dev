//
//  LoginScreen.swift
//  NavigationStackExample
//
//  Created by mybkhn on 2021/04/02.
//

import SwiftUI

struct LoginScreen: View {
	let navigationStack: NavigationStack
	let router: MyRouter

	@State var isPushHomeScreen: Bool = false

    var body: some View {
		PushView(destination: HomeScreen(),
				 destinationId: "home",
				 isActive: $isPushHomeScreen, label: {})
		
		Button(action: {
//			self.router.toHome()
			self.isPushHomeScreen = true
		}, label: {
			Text("Home")
		})
    }
}
