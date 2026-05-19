// TabContentView.swift / HTCFiPad
// Copyright © 2021 Hitachi, Ltd.

import SwiftUI

// 902_新規持出アップロード / 903_追加持出アップロード / 209_設定
struct TabContentView: View {

	let tabWidth = UIScreen.main.bounds.width / 3.0

	var body: some View {
		VStack {
			Divider()

			HStack {
				Button(action: {

                }, label: {
					Text("Tab 1")
						.foregroundColor(.blue)
                })
				.frame(width: tabWidth, alignment: .center)

				Button(action: {

				}, label: {
					Text("Tab 2")
						.foregroundColor(.blue)
                })
				.frame(width: tabWidth, alignment: .center)

				Button(action: {

				}, label: {
					Text("Tab 3")
						.foregroundColor(.blue)
                })
				.frame(width: tabWidth, alignment: .center)
			}
			.animation(.spring())

        }
	}
}
