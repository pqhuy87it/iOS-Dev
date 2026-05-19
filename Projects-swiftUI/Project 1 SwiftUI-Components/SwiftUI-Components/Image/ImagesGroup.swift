//
//  ImagesGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct ImagesGroup: View {
	var body: some View {
		Group {
			SectionView(
				headerTitle: "Image",
				footerTitle: "A view that displays an environment-dependent image.",
				content: {
					Image("Waterfall")
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(maxHeight: 128)
				}
			)

			SectionView(
				headerTitle: "System Images",
				footerTitle: "Built-in icons that represent common tasks and types of content in a variety of use cases. The full list of icons is available in the SF Symbols app.",
				content: {
					Group {
						Image(systemName: "memories.badge.plus")
							// This modifier lets you use the new multi-color system icons in SF Symbols 2
							.renderingMode(.original)
						Image(systemName: "memories.badge.plus")
					}
				}
			)

			SectionView(
				headerTitle: "Label",
				footerTitle: "A standard label for user interface items, consisting of an icon with a title.",
				content: {
					Group {
						Label("Rain", systemImage: "cloud.rain")
						Label("Snow", systemImage: "snow")
						Label("Sun", systemImage: "sun.max")
					}
				}
			)
		}
	}
}

struct ImagesGroup_Previews: PreviewProvider {
	static var previews: some View {
		ImagesGroup()
			.previewLayout(.sizeThatFits)
	}
}
