//
//  Binding+Extension.swift
//  PickerOnChange
//
//  Created by mybkhn on 2021/03/23.
//

import SwiftUI

extension Binding {
	func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
		return Binding(
			get: { self.wrappedValue },
			set: { selection in
				self.wrappedValue = selection
				handler(selection)
			})
	}
}
