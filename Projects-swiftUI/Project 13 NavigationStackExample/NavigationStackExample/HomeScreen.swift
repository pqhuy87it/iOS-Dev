//
//  HomeScreen.swift
//  NavigationStackExample
//
//  Created by mybkhn on 2021/04/02.
//

import SwiftUI

struct HomeScreen: View {
	@State var isPushSignUpScreen: Bool = false

	var body: some View {
		VStack {
			PushView(destination: SignUpScreen(),
					 destinationId: "signup",
					 isActive: $isPushSignUpScreen, label: {})
			Button {
				self.isPushSignUpScreen = true
			} label: {
				Text("Push Sign Up Screen")
			}


			Spacer()

			TabContentView()
		}
		.navigationBarTitle("Home", displayMode: .inline)
	}
}
