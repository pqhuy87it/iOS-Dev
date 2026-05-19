//
//  GridViewHeader.swift
//  SegmentedControlExample
//
//  Created by mybkhn on 2021/02/03.
//

import SwiftUI

extension HorizontalAlignment {
	private enum UnderlineLeading: AlignmentID {
		static func defaultValue(in d: ViewDimensions) -> CGFloat {
			return d[.leading]
		}
	}

	static let underlineLeading = HorizontalAlignment(UnderlineLeading.self)
}

struct GridViewHeader : View {

	@State private var activeIdx: Int = 0
	@State private var w: [CGFloat] = [0, 0, 0, 0]

	var body: some View {
		return VStack(alignment: .underlineLeading) {
			HStack {
				Text("Tweets").modifier(MagicStuff(activeIdx: $activeIdx, widths: $w, idx: 0))
				Spacer()
				Text("Tweets & Replies").modifier(MagicStuff(activeIdx: $activeIdx, widths: $w, idx: 1))
				Spacer()
				Text("Media").modifier(MagicStuff(activeIdx: $activeIdx, widths: $w, idx: 2))
				Spacer()
				Text("Likes").modifier(MagicStuff(activeIdx: $activeIdx, widths: $w, idx: 3))
			}
			.frame(height: 50)
			.padding(.horizontal, 10)
			Rectangle()
				.alignmentGuide(.underlineLeading) { d in d[.leading]  }
				.frame(width: w[activeIdx],  height: 2)
				.animation(.linear)
		}
	}
}
