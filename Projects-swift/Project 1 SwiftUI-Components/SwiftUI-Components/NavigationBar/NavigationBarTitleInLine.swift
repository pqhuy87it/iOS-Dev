//
//  NavigationBarTitleInLine.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct NavigationBarTitleInLine: View {
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
			.navigationBarTitle(Text("Inline Title"), displayMode: .inline)
    }
}

struct NavigationBarTitleInLine_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBarTitleInLine()
    }
}
