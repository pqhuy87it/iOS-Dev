//
//  PasswordConditionDisplay.swift
//  onReceiveJustExample
//
//  Created by mybkhn on 2021/06/30.
//

import SwiftUI

struct PasswordConditionDisplay: View {
	@Binding var isConditionMet: Bool
	var conditionName: String
	var body: some View {
		HStack {
			Image(systemName: isConditionMet ? "circle.fill" : "xmark")
				.padding(.horizontal, 5)
			Text(conditionName)
		}
	}
}
