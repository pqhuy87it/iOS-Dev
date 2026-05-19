//
//  AnyTransitionExtension.swift
//  transiftion-cross-effect
//
//  Created by mybkhn on 2021/06/14.
//

import SwiftUI

extension AnyTransition {
	static var rectangular: AnyTransition { get {
		AnyTransition.modifier(
			active: ShapeClipModifier(shape: RectangularShape(pct: 1)),
			identity: ShapeClipModifier(shape: RectangularShape(pct: 0)))
	}
	}

	static var circular: AnyTransition { get {
		AnyTransition.modifier(
			active: ShapeClipModifier(shape: CircleClipShape(pct: 1)),
			identity: ShapeClipModifier(shape: CircleClipShape(pct: 0)))
	}
	}

	static func stripes(stripes s: Int, horizontal h: Bool) -> AnyTransition {

		return AnyTransition.asymmetric(
			insertion: AnyTransition.modifier(
				active: ShapeClipModifier(shape: StripesShape(insertion: true, pct: 1, stripes: s, horizontal: h)),
				identity: ShapeClipModifier(shape: StripesShape(insertion: true, pct: 0, stripes: s, horizontal: h))),
			removal: AnyTransition.modifier(
				active: ShapeClipModifier(shape: StripesShape(insertion: false, pct: 1, stripes: s, horizontal: h)),
				identity: ShapeClipModifier(shape: StripesShape(insertion: false, pct: 0, stripes: s, horizontal: h))))
	}

}
