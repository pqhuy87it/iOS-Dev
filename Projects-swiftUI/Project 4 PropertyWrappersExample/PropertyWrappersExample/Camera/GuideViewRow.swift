

import SwiftUI
import UIKit

private let spacing: CGFloat = 0 // 項目間隔
private let maxWidth: CGFloat = UIScreen.main.bounds.width / 2 // テキストの最大幅

// 905_カメラ
struct GuideViewRow: View {
	var guideSize: String

	var body: some View {
		VStack(spacing: spacing) {
			Text(guideSize)
				.foregroundColor(Color.blue)
		}.frame(maxWidth: maxWidth, alignment: .leading)
	}
}
