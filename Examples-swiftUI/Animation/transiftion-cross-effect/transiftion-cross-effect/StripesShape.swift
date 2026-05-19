//
//  StripesShape.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

struct StripesShape: Shape {
	let insertion: Bool
	var pct: CGFloat
	let stripes: Int
	let horizontal: Bool

	var animatableData: CGFloat {
		get { pct }
		set { pct = newValue }
	}

	func path(in rect: CGRect) -> Path {
		var path = Path()

		if horizontal {
			let stripeHeight = rect.height / CGFloat(stripes)

			for i in 0..<(stripes) {
				let j = CGFloat(i)

				if insertion {
					path.addRect(CGRect(x: 0, y: j * stripeHeight, width: rect.width, height: stripeHeight * (1-pct)))
				} else {
					path.addRect(CGRect(x: 0, y: j * stripeHeight + (stripeHeight * pct), width: rect.width, height: stripeHeight * (1-pct)))
				}
			}
		} else {
			let stripeWidth = rect.width / CGFloat(stripes)

			for i in 0..<(stripes) {
				let j = CGFloat(i)

				if insertion {
					path.addRect(CGRect(x: j * stripeWidth, y: 0, width: stripeWidth * (1-pct), height: rect.height))
				} else {
					path.addRect(CGRect(x: j * stripeWidth + (stripeWidth * pct), y: 0, width: stripeWidth * (1-pct), height: rect.height))
				}
			}
		}

		return path
	}
}
