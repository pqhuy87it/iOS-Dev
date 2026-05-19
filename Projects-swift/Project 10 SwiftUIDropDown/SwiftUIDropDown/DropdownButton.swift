//
//  DropdownButton.swift
//  SwiftUIDropDown
//
//  Created by mybkhn on 2021/03/21.
//

import SwiftUI

struct DropdownButton: View {
	@State var shouldShowDropdown = false
	@Binding var displayText: String
	var options: [DropdownOption]
	var onSelect: ((_ key: String) -> Void)?

	let buttonHeight: CGFloat = 30
	var body: some View {
		Button(action: {
			self.shouldShowDropdown.toggle()
		}) {
			HStack {
				Text(displayText)
				Spacer()
					.frame(width: 20)
				Image(systemName: self.shouldShowDropdown ? "chevron.up" : "chevron.down")
			}
		}
		.padding(.horizontal)
		.cornerRadius(dropdownCornerRadius)
		.frame(height: self.buttonHeight)
		.overlay(
			RoundedRectangle(cornerRadius: dropdownCornerRadius)
				.stroke(Color.gray, lineWidth: 1)
		)
		.overlay(
			VStack {
				if self.shouldShowDropdown {
					Spacer(minLength: buttonHeight + 10)
					Dropdown(options: self.options, onSelect: self.onSelect)
				}
			}, alignment: .topLeading
		)
		.background(
			RoundedRectangle(cornerRadius: dropdownCornerRadius).fill(Color.white)
		)
	}
}
