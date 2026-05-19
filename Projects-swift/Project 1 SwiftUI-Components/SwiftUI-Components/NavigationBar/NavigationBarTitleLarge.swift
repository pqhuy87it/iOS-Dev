//
//  NavigationBarTitleLarge.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct NavigationBarTitleLarge: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
			.navigationBarTitle(Text("Large Title"), displayMode: .large)
    }
}

struct NavigationBarTitleLarge_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBarTitleLarge()
    }
}
