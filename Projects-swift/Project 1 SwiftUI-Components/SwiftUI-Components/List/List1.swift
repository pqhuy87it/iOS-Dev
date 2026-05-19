//
//  List1.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct List1: View {
    var body: some View {
		List(0..<30) { item in
			Text("Hello World !")
		}
    }
}

struct List1_Previews: PreviewProvider {
    static var previews: some View {
        List1()
    }
}
