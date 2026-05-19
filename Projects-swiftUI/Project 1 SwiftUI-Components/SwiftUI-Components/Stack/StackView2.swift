//
//  StackView2.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct StackView2: View {
    var body: some View {
		ZStack(alignment:.topTrailing) {
			HStack() {
				Text("Text 1")
			}
			.frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 200, alignment: .center)
			.background(Color.red)
			HStack() {
				Text("Text 2")
			}
			.frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			.background(Color.blue)
		}
    }
}

struct StackView2_Previews: PreviewProvider {
    static var previews: some View {
        StackView2()
    }
}
