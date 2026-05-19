//
//  SignUpScreen.swift
//  NavigationStackExample
//
//  Created by mybkhn on 2021/04/02.
//

import SwiftUI

struct SignUpScreen: View {
	@State var isPopToHome: Bool = false

    var body: some View {
		VStack {
			PopView(destination: .view(withId: "home"), destinationView: HomeScreen(), isActive: $isPopToHome, label: {})

			Button {
				self.isPopToHome = true
			} label: {
				Text("Pop to home")
			}
		}
    }
}

struct SignUpScreen_Previews: PreviewProvider {
    static var previews: some View {
        SignUpScreen()
    }
}
