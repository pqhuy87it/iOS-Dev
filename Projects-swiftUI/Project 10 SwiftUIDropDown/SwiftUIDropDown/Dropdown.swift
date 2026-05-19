//
//  Dropdown.swift
//  SwiftUIDropDown
//
//  Created by mybkhn on 2021/03/21.
//

import SwiftUI

struct Dropdown: View {
	var options: [DropdownOption]
	var onSelect: ((_ key: String) -> Void)?

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(self.options, id: \.self) { option in
				DropdownOptionElement(val: option.val, key: option.key, onSelect: self.onSelect)
			}
		}

		.background(Color.white)
		.cornerRadius(dropdownCornerRadius)
		.overlay(
			RoundedRectangle(cornerRadius: dropdownCornerRadius)
				.stroke(Color.gray, lineWidth: 1)
		)
	}
}

