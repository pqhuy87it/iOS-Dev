//
//  ShapeClipModifier.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct ShapeClipModifier<S: Shape>: ViewModifier {
	let shape: S

	func body(content: Content) -> some View {
		content.clipShape(shape)
	}
}
