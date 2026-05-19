//
//  ContentView.swift
//  SwiftUIDropDown
//
//  Created by mybkhn on 2021/03/21.
//

import SwiftUI

let dropdownCornerRadius: CGFloat = 4.0

struct ContentView: View {

	@State var displayText: String = "Select option"

    var body: some View {
		DropdownButton(displayText: $displayText, options: [
			DropdownOption.init(key: "key1", val: "Option 1"),
			DropdownOption.init(key: "key2", val: "Option 2"),
			DropdownOption.init(key: "key3", val: "Option 3")
		])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
