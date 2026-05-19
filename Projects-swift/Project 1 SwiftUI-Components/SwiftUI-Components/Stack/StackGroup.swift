//
//  StackGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct StackGroup: View {
    var body: some View {
		List {
			Display(title: "Stack view 1", icon: "text.aligncenter", content: { StackView1()})
			Display(title: "Stack view 2", icon: "text.aligncenter", content: { StackView2()})
			Display(title: "Stack view 3", icon: "text.aligncenter", content: { StackView3()})
		}
    }
}

struct StackGroup_Previews: PreviewProvider {
    static var previews: some View {
        StackGroup()
    }
}
