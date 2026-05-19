//
//  ContentView.swift
//  Advanced SwiftUI Transitions
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct ContentView: View {
	@State private var show = false

	var body: some View {

		return ZStack {
			Button("Open Booking") {
				withAnimation(.easeInOut(duration: 0.8)) {
					self.show = true
				}
			}

			if show {
				RoundedRectangle(cornerRadius: 15)
					.fill(Color.pink).overlay(MyForm(show: $show))
					.frame(width: 400, height: 500)
					.shadow(color: .black, radius: 3)
					.transition(.fly)
					.zIndex(1)
			}
		}
	}
}

