//
//  HapticsGroup.swift
//  SwiftUI-Components
//
//  Created by mybkhn on 2021/02/05.
//

import SwiftUI

struct HapticsGroup: View {
	var body: some View {
		Group {
			SectionView(
				headerTitle: "UIImpactFeedbackGenerator",
				footerTitle: "Haptic feedback provides a tactile response.",
				content: {
					Group {
						Button(action: { playFeedbackHaptic(.heavy) }) {
							Text("heavy")
						}

						Button(action: { playFeedbackHaptic(.light) }) {
							Text("light")
						}

						Button(action: { playFeedbackHaptic(.medium) }) {
							Text("medium")
						}

						Button(action: { playFeedbackHaptic(.rigid) }) {
							Text("rigid")
						}

						Button(action: { playFeedbackHaptic(.soft) }) {
							Text("soft")
						}
					}
				}
			)

			SectionView(
				headerTitle: "UINotificationFeedbackGenerator",
				footerTitle: "Haptics to communicate successes, failures, and warnings.",
				content: {
					Group {
						Button(action: { playNotificationHaptic(.error) }) {
							Text("error")
						}

						Button(action: { playNotificationHaptic(.success) }) {
							Text("success")
						}

						Button(action: { playNotificationHaptic(.warning) }) {
							Text("warning")
						}
					}
				}
			)
		}
	}

	func playFeedbackHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
		let generator = UIImpactFeedbackGenerator(style: style)
		generator.impactOccurred()
	}

	func playNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
		let generator = UINotificationFeedbackGenerator()
		generator.notificationOccurred(type)
	}
}

struct HapticsGroup_Previews: PreviewProvider {
	static var previews: some View {
		HapticsGroup()
			.previewLayout(.sizeThatFits)
	}
}
