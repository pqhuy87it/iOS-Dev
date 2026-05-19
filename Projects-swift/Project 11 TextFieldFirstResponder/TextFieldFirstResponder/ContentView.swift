//
//  ContentView.swift
//  TextFieldFirstResponder
//
//  Created by mybkhn on 2021/03/14.
//

import SwiftUI

struct ContentView: View {
	@State var text: String = ""
	@State var isFirstResponder = false

    var body: some View {
		VStack {
			HStack {
				Button(action: {
					self.isFirstResponder = true
				}, label: {
					Text("Tap here!")
				})

				CustomTextField(text: $text, isFirstResponder: isFirstResponder)
					.frame(width: 300, height: 50)
					.background(Color.red)
			}
		}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
