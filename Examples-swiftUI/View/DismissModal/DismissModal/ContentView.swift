//
//  ContentView.swift
//  DismissModal
//
//  Created by mybkhn on 2021/02/04.
//

import SwiftUI

struct ContentView: View {
	@State private var showModal = false

    var body: some View {
		Button("Show Modal") {
			self.showModal.toggle()
		}.sheet(isPresented: $showModal) {
			ModalView(showModal: self.$showModal)
		}
    }
}

struct ModalView: View {
	@Binding var showModal: Bool

	var body: some View {
		Text("Modal view")
		Button("Dismiss") {
			self.showModal.toggle()
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
