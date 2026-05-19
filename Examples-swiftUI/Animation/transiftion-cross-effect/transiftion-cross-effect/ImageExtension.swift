//
//  ImageExtension.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

extension Image {
	func photoStyle(height: CGFloat) -> some View {
		let shape = RoundedRectangle(cornerRadius: 15)

		return self.resizable()
			.aspectRatio(contentMode: .fit)
			.frame(height: height)
			.clipShape(shape)
			.overlay(shape.stroke(Color.white, lineWidth: 2))
			.padding(2)
			.overlay(shape.strokeBorder(Color.black.opacity(0.1)))
			.shadow(radius: 2)
			.padding(4)
	}
}
