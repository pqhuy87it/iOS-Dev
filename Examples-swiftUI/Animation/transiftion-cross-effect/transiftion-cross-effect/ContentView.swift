//
//  ContentView.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct ContentView: View {
	let animationDuration: Double = 2
	let images = ["photo1", "photo2", "photo3", "photo4"]
	@State private var idx = 0
	@State private var transitionType: Int = 2

	var transition: AnyTransition {
		if transitionType == 0 {
			return .opacity
		} else if transitionType == 1 {
			return .scale
		} else if transitionType == 2 {
			return .circular
		} else if transitionType == 3 {
			return .rectangular
		} else if transitionType == 4 {
			return .stripes(stripes: 50, horizontal: true)
		} else if transitionType == 5 {
			return .stripes(stripes: 50, horizontal: false)
		} else {
			return .opacity
		}
	}

	var body: some View {
		VStack {
			Text("Picture Show").padding(.bottom, 0)

			ZStack {
				ForEach(self.images.indices) { i in
					if self.idx == i {
						Image(self.images[i]).photoStyle(height: 530)
							.transition(self.transition)
					}
				}

			}

			Picker(selection: self.$transitionType, label: EmptyView()) {
				Text(".opacity").tag(0)
				Text(".scale").tag(1)
				Text(".circular").tag(2)
				Text(".rectangular").tag(3)
				Text(".stripes(H)").tag(4)
				Text(".stripes(V)").tag(5)
			}.pickerStyle(SegmentedPickerStyle()).frame(width: 800)
			.padding(.top, 20)

			HStack(spacing: 20) {
				Button(action: {
					withAnimation(.easeInOut(duration: self.animationDuration)) {
						self.idx = self.idx > 0 ? self.idx - 1 : self.images.count - 1
					}
				}) {
					Image(systemName: "arrow.left.circle.fill")
				}

				Button(action: {
					withAnimation(.easeInOut(duration: self.animationDuration)) {
						self.idx = self.idx < (self.images.count - 1) ? self.idx + 1 : 0
					}
				}) {
					Image(systemName: "arrow.right.circle.fill")
				}
			}.padding(.top, 20)

		}.font(.largeTitle)
	}
}
