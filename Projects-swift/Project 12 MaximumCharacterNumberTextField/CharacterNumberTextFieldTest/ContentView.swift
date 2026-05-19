//
//  ContentView.swift
//  CharacterNumberTextFieldTest
//
//  Created by mybkhn on 2021/04/25.
//

import SwiftUI

struct ContentView: View {
	@State var text: String = ""

    var body: some View {
		CharacterNumberTextField("Input Name", text: $text)
			.maximumDigits(20)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
