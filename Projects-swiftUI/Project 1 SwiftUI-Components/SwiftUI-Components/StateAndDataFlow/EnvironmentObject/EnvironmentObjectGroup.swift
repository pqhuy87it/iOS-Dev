//
//  EnvironmentObjectGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/26.
//

import SwiftUI

struct EnvironmentObjectGroup: View {
	@EnvironmentObject var passObject: PassValueObject
	@State private var isActive = false
	
    var body: some View {
		NavigationLink(destination: ChildView1().environmentObject(passObject),isActive: $isActive) {
			Button(action: {
				self.isActive = true
			}, label: {
				Text("Open")
			})
		}

		VStack {
			Text(self.passObject.value)
		}
    }
}

struct EnvironmentObjectGroup_Previews: PreviewProvider {
    static var previews: some View {
        EnvironmentObjectGroup()
    }
}
