//
//  CircleClipShape.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct CircleClipShape: Shape {
	var pct: CGFloat

	var animatableData: CGFloat {
		get { pct }
		set { pct = newValue }
	}

	func path(in rect: CGRect) -> Path {
		var path = Path()
		var bigRect = rect
		bigRect.size.width = bigRect.size.width * 2 * (1-pct)
		bigRect.size.height = bigRect.size.height * 2 * (1-pct)
		bigRect = bigRect.offsetBy(dx: -rect.width/2.0, dy: -rect.height/2.0)

		path = Circle().path(in: bigRect)

		return path
	}
}
