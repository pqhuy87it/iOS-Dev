//
//  ContentView.swift
//  ConditionallyUseView
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct ContentView: View {
	@State private var isLogin = true

//	@ViewBuilder
    var body: some View {
		if self.isLogin {
			MainView()
		} else {
			LoginView()
		}
    }
}

struct MainView: View {
	var body: some View {
		Text("MainView")
			.padding()
	}
}

struct LoginView: View {
	var body: some View {
		Text("LoginView")
			.padding()
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
