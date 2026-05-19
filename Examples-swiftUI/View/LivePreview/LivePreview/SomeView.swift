//
//  SomeView.swift
//  LivePreview
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct SomeView: View {
	@Binding var code: String

	var body: some View {
		Text("Hello, world! \(code)")
			.padding()
	}
}

struct SomeView_Previews: PreviewProvider {
	static var previews: some View {
		PreviewWrapper()
	}

	struct PreviewWrapper: View {
		@State(initialValue: "I'm here.") var code: String

		var body: some View {
			SomeView(code: $code)
		}
	}
}
