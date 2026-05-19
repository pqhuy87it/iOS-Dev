//
//  NavigationBarGroup.swift
//  SwiftUI-Components
//
//  Created by Pham Quang Huy on 2021/01/23.
//

import SwiftUI

struct NavigationBarGroup: View {
    
    var body: some View {
		List {
			Display(title: "Setup NavigationBar", icon: "text.aligncenter", content: { SetupNavigationBar() })
			Display(title: "NavigationBar Title Large", icon: "text.aligncenter", content: { NavigationBarTitleLarge() })
			Display(title: "NavigationBar Inline", icon: "text.aligncenter", content: { NavigationBarTitleInLine() })
			Display(title: "NavigationBar Auto", icon: "text.aligncenter", content: { NavigationBarTitleAuto() })
		}
    }
    
    
}

struct NavigationBarGroup_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBarGroup()
    }
}
