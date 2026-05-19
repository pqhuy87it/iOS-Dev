//
//  StateAndDataFlow.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/26.
//

import SwiftUI

struct StateAndDataFlowGroup: View {
	let passValueObject = PassValueObject()

    var body: some View {
		List {
			Display(title: "EnvironmentObject", icon: "text.aligncenter", content: {
						EnvironmentObjectGroup()
							.environmentObject(passValueObject)

			})
		}
    }
}

