//
//  ListsGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct ListsGroup: View {
    var body: some View {
		List {
			Display(title: "List 1", icon: "text.aligncenter", content: { List1() })
			Display(title: "List 2", icon: "text.aligncenter", content: { List2() })
			Display(title: "List 3", icon: "text.aligncenter", content: { List3() })
		}
    }
}

struct ListsGroup_Previews: PreviewProvider {
    static var previews: some View {
        ListsGroup()
    }
}
