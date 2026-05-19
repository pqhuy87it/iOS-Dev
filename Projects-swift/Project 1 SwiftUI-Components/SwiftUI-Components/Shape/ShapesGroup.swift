//
//  ShapesGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct ShapesGroup: View {

	// Define constraints for the shape frames so they don’t stretch out too much on macOS
	let frameMinWidth: CGFloat = 16
	let frameMaxWidth: CGFloat = 256
	let frameMinHeight: CGFloat = 32
	let frameMaxHeight: CGFloat = 64

	var body: some View {
		Group {
			SectionView(
				headerTitle: "Rectangle",
				footerTitle: "A rectangular shape aligned inside the frame of the view containing it.",
				content: {
					Rectangle()
						.frame(
							minWidth: frameMinWidth,
							maxWidth: frameMaxWidth,
							minHeight: frameMinHeight,
							maxHeight: frameMaxHeight)
				}
			)

			SectionView(
				headerTitle: "RoundedRectangle",
				footerTitle: "A rectangular shape with rounded corners, aligned inside the frame of the view containing it.",
				content: {
					RoundedRectangle(cornerRadius: 4)
						.frame(
							minWidth: frameMinWidth,
							maxWidth: frameMaxWidth,
							minHeight: frameMinHeight,
							maxHeight: frameMaxHeight)
				}
			)

			SectionView(
				headerTitle: "Circle",
				footerTitle: "A circle centered on the frame of the view containing it.",
				content: {
					Circle()
						.frame(
							minWidth: frameMinWidth,
							maxWidth: frameMaxWidth,
							minHeight: frameMinHeight,
							maxHeight: frameMaxHeight)
				}
			)

			SectionView(
				headerTitle: "Ellipse",
				footerTitle: "An ellipse aligned inside the frame of the view containing it.",
				content: {
					Ellipse()
						.frame(
							minWidth: frameMinWidth,
							maxWidth: frameMaxWidth,
							minHeight: frameMinHeight,
							maxHeight: frameMaxHeight)
				}
			)

			SectionView(
				headerTitle: "Capsule",
				footerTitle: "A capsule shape aligned inside the frame of the view containing it.",
				content: {
					Capsule()
						.frame(
							minWidth: frameMinWidth,
							maxWidth: frameMaxWidth,
							minHeight: frameMinHeight,
							maxHeight: frameMaxHeight)
				}
			)
		}
	}
}

struct ShapesGroup_Previews: PreviewProvider {
	static var previews: some View {
		ShapesGroup()
			.previewLayout(.sizeThatFits)
	}
}
