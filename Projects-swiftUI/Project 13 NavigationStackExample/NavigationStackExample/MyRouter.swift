//
//  MyRouter.swift
//  NavigationStackExample
//
//  Created by mybkhn on 2021/04/02.
//

import SwiftUI

class MyRouter {
	private let navStack: NavigationStack

	init(navStack: NavigationStack) {
		self.navStack = navStack
	}

	func toSignUp() {
		self.navStack.push(SignUpScreen(), withId: "signup")
	}

	func toHome() {
		self.navStack.push(HomeScreen(), withId: "home")
	}

	func popLogin() {
		self.navStack.pop(to: .root)
	}
}
