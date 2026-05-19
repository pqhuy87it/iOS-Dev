//
//  StackView1.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct StackView1: View {
    var body: some View {
		VStack(alignment:.leading) {
			HStack() {
				Text("Text 1")
			}
			.frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 200, alignment: .center)
			.padding(.top)
			.background(Color.red)
			HStack() {
				Text("Text 2")
			}
			.frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			.background(Color.blue)
			HStack() {
				Text("Text 3")
			}
			.frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 200, alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/)
			.background(Color.yellow)
		}
		//		.edgesIgnoringSafeArea(.all)
		//		.padding(.vertical, 10)
		//		.padding(.horizontal, 5)
		//		.alignmentGuide(HorizontalAlignment.leading, computeValue: { dimension in
		//			dimension.width*0.8
		//		})
		//		.alignmentGuide(VerticalAlignment.top, computeValue: { dimension in
		//			dimension.height*0.8
		//		})
		.background(Color.gray)
    }
}

struct StackView1_Previews: PreviewProvider {
    static var previews: some View {
        StackView1()
    }
}
