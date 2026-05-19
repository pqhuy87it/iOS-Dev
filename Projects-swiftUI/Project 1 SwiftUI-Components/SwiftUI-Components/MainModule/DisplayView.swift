//
//  DisplayView.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct DisplayView<Content: View>: View {
	var title: String
	let content: () -> Content

	var body: some View {
		return content()
		.listStyle(InsetGroupedListStyle())
		.navigationBarTitle(title, displayMode: .inline)
	}
}

struct Display<Content: View>: View {
	var title: String
	var icon: String
	var content: () -> Content

	var body: some View {
		NavigationLink(destination: DisplayView(title: title, content: content)) {
			Label(title, systemImage: icon).font(.headline).padding(.vertical, 8)
		}
	}
}

struct DisplayView_Previews: PreviewProvider {
    static var previews: some View {
		DisplayView(title: "Group", content: { Text("Content") })
			.previewLayout(.sizeThatFits)
    }
}
