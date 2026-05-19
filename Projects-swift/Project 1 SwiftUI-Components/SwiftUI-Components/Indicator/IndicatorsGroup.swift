//
//  IndicatorsGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct IndicatorsGroup: View {
	@State private var progressAmount = 0.0
	@State private var progress = 0.5

	let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

	var body: some View {
		Group {
			SectionView(
				headerTitle: "ProgressView",
				footerTitle: "A view that shows the progress towards completion of a task.",
				content: {
					Group {
						ProgressView()
						VStack {
							ProgressView("Downloading...", value: progressAmount, total: 100)
						}
						.onReceive(timer) { _ in
							if progressAmount < 100 {
								progressAmount += 2
							} else {
								DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
									progressAmount = 0.0
								}

							}
						}
					}
				}
			)
		}
	}
}

struct IndicatorsGroup_Previews: PreviewProvider {
	static var previews: some View {
		IndicatorsGroup()
			.previewLayout(.sizeThatFits)
	}
}
