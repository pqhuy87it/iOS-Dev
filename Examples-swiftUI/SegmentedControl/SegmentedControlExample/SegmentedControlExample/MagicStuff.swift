//
//  MagicStuff.swift
//  SegmentedControlExample
//
//  Created by mybkhn on 2021/02/03.
//

import SwiftUI

struct MagicStuff: ViewModifier {
	@Binding var activeIdx: Int
	@Binding var widths: [CGFloat]
	let idx: Int

	func body(content: Content) -> some View {
		Group {
			if activeIdx == idx {
				content.alignmentGuide(.underlineLeading) { d in
					DispatchQueue.main.async { self.widths[self.idx] = d.width }

					return d[.leading]
				}.onTapGesture { self.activeIdx = self.idx }

			} else {
				content.onTapGesture { self.activeIdx = self.idx }
			}
		}
	}
}
