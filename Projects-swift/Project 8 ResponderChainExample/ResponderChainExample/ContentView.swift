//
//  ContentView.swift
//  ResponderChainExample
//
//  Created by mybkhn on 2021/03/14.
//

import SwiftUI
import ResponderChain

struct ContentView: View {
	@EnvironmentObject var chain: ResponderChain

	var body: some View {
		VStack(spacing: 20) {
			// Show which view is first responder
			Text("Selected field: \(chain.firstResponder?.description ?? "Nothing selected")")

			// Some views that can become first responder
			TextField("0", text: .constant(""), onCommit: { chain.firstResponder = "1" }).responderTag("0")
			TextField("1", text: .constant(""), onCommit: { chain.firstResponder = "2" }).responderTag("1")
			TextField("2", text: .constant(""), onCommit: { chain.firstResponder = "3" }).responderTag("2")
			TextField("3", text: .constant(""), onCommit: { chain.firstResponder = nil }).responderTag("3")

			// Buttons to change first responder
			HStack {
				Button("Select 0", action: { chain.firstResponder = "0" })
				Button("Select 1", action: { chain.firstResponder = "1" })
				Button("Select 2", action: { chain.firstResponder = "2" })
				Button("Select 3", action: { chain.firstResponder = "3" })
			}
		}
		.padding()
		.onAppear {
			// Set first responder on appear
			DispatchQueue.main.async {
				chain.firstResponder = "0"
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
