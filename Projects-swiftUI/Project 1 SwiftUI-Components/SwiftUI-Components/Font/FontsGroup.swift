//
//  FontsGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct FontsGroup: View {
    var body: some View {
		Group {
			Group {
				SectionView(headerTitle: "A font with the large title text style.") {
					Text("largeTitle")
						.font(.largeTitle)
				}

				SectionView(headerTitle: "A font with the title text style.") {
					Text("title")
						.font(.title)
				}

				SectionView(headerTitle: "Create a font for second level hierarchical headings.") {
					Text("title2")
						.font(.title2)
				}

				SectionView(headerTitle: "Create a font for third level hierarchical headings.") {
					Text("title3")
						.font(.title3)
				}
			}

			Group {
				SectionView(headerTitle: "A font with the headline text style.") {
					Text("headline")
						.font(.headline)
				}

				SectionView(headerTitle: "A font with the subheadline text style.") {
					Text("subheadline")
						.font(.subheadline)
				}
			}

			SectionView(headerTitle: "A font with the body text style.") {
				Text("body")
					.font(.body)
			}

			SectionView(headerTitle: "A font with the callout text style.") {
				Text("callout")
					.font(.callout)
			}

			Group {
				SectionView(headerTitle: "A font with the caption text style.") {
					Text("caption")
						.font(.caption)
				}

				SectionView(headerTitle: "Create a font with the alternate caption text style.") {
					Text("caption2")
						.font(.caption2)
				}
			}

			SectionView(headerTitle: "A font with the footnote text style.") {
				Text("footnote")
					.font(.footnote)
			}
		}
    }
}

struct FontsGroup_Previews: PreviewProvider {
    static var previews: some View {
        FontsGroup()
    }
}
