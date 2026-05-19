//
//  NavigationBarTitleAuto.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct NavigationBarTitleAuto: View {
    var body: some View {
		List(0..<30) { item in
			Text("Hello World !")
		}
		.navigationBarTitle(Text("Automatic Title"), displayMode: .automatic)
    }
}

struct NavigationBarTitleAuto_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBarTitleAuto()
    }
}
