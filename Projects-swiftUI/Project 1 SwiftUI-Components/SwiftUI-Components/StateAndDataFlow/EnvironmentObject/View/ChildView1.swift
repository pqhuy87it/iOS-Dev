//
//  ChildView1.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/26.
//

import SwiftUI

struct ChildView1: View {

	@EnvironmentObject var passValue: PassValueObject

    var body: some View {
		TextField("Trade Name", text: self.$passValue.value)
			.textFieldStyle(RoundedBorderTextFieldStyle())
			.padding()
    }
}

struct ChildView1_Previews: PreviewProvider {
    static var previews: some View {
        ChildView1()
    }
}
