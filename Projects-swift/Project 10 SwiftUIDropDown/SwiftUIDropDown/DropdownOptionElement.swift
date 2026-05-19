//
//  DropdownOptionElement.swift
//  SwiftUIDropDown
//
//  Created by mybkhn on 2021/03/21.
//

import SwiftUI

struct DropdownOptionElement: View {
	var val: String
	var key: String
	var onSelect: ((_ key: String) -> Void)?

	var body: some View {
		Button(action: {
			if let onSelect = self.onSelect {
				onSelect(self.key)
			}
		}) {
			Text(self.val)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 5)
	}
}
