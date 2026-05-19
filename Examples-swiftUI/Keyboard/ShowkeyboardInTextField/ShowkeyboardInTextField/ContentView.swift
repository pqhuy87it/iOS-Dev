//
//  ContentView.swift
//  ShowkeyboardInTextField
//
//  Created by mybkhn on 2021/02/03.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject private var keyboard = KeyboardResponder()
	@State private var textFieldInput: String = ""

	var body: some View {
		VStack {
			HStack {
				TextField("uMessage", text: $textFieldInput)
			}
		}.padding()
		.padding(.bottom, keyboard.currentHeight)
		.edgesIgnoringSafeArea(.bottom)
		.animation(.easeOut(duration: 0.4))
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
