//
//  ContentView.swift
//  MultilineTextField
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct ContentView: View {
	@State private var text = "abc"
    var body: some View {
		MultilineTextField(text: $text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
