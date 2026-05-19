//
//  MultilineTextField.swift
//  MultilineTextField
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct MultilineTextField: View {

	private var placeholder: String
	private var onCommit: (() -> Void)?

	@Binding private var text: String
	private var internalText: Binding<String> {
		Binding<String>(get: { self.text } ) {
			self.text = $0
			self.showingPlaceholder = $0.isEmpty
		}
	}

	@State private var dynamicHeight: CGFloat = 100
	@State private var showingPlaceholder = false

	init (_ placeholder: String = "", text: Binding<String>, onCommit: (() -> Void)? = nil) {
		self.placeholder = placeholder
		self.onCommit = onCommit
		self._text = text
		self._showingPlaceholder = State<Bool>(initialValue: self.text.isEmpty)
	}

	var body: some View {
		UITextViewWrapper(text: self.internalText, calculatedHeight: $dynamicHeight, onDone: onCommit)
			.frame(minHeight: dynamicHeight, maxHeight: dynamicHeight)
			.background(placeholderView, alignment: .topLeading)
	}

	var placeholderView: some View {
		Group {
			if showingPlaceholder {
				Text(placeholder)
					.foregroundColor(.gray)
					.padding(.leading, 4)
					.padding(.top, 8)
			}
		}
	}
}

#if DEBUG
struct MultilineTextField_Previews: PreviewProvider {
	static var test:String = ""//some very very very long description string to be initially wider than screen"
	static var testBinding = Binding<String>(get: { test }, set: {
												//        print("New value: \($0)")
												test = $0 } )

	static var previews: some View {
		VStack(alignment: .leading) {
			Text("Description:")
			MultilineTextField("Enter some text here", text: testBinding, onCommit: {
				print("Final text: \(test)")
			})
			.overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black))
			Text("Something static here...")
			Spacer()
		}
		.padding()
	}
}
#endif
