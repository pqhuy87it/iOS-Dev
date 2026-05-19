//
//  ContentView.swift
//  PickerOnChange
//
//  Created by mybkhn on 2021/03/23.
//

import SwiftUI

struct ContentView: View {
	@State private var favoriteColor = 0
	
    var body: some View {
		Picker(selection: $favoriteColor.onChange(color), label: Text("Color")) {
			Text("Red").tag(0)
			Text("Green").tag(1)
			Text("Blue").tag(2)
		}
    }

	func color(_ tag: Int) {
		print("Color tag: \(tag)")
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
