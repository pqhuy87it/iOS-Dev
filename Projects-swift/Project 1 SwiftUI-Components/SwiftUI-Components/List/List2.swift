//
//  List2.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct List2: View {
    var body: some View {
		List {
			Section(header: Text("Header")) {
				Text("1")
				Text("2")
				Text("3")
			}

			Section(footer: Text("Footer")) {
				Text("4")
				Text("5")
				Text("6")
			}

			Section(header: Text("Header"), footer: Text("Footer")) {
				Text("7")
				Text("8")
				Text("9")
			}
		}
    }
}

struct List2_Previews: PreviewProvider {
    static var previews: some View {
        List2()
    }
}
