//
//  RectangularShape.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct RectangularShape: Shape {
	var pct: CGFloat

	var animatableData: CGFloat {
		get { pct }
		set { pct = newValue }
	}

	func path(in rect: CGRect) -> Path {
		var path = Path()

		path.addRect(rect.insetBy(dx: pct * rect.width / 2.0, dy: pct * rect.height / 2.0))

		return path
	}
}
