//
//  ContentView.swift
//  PageViewWithKeyboard
//
//  Created by Pham Quang Huy on 2021/03/08.
//

import SwiftUI

struct ContentView: View {
    @State var index: Int = 0
	@State private var showFirstAlert = false
    
    var body: some View {
		NavigationView {
			VStack {
				HStack {
					Button(action: {
						self.index = (self.index == 0) ? self.index : (self.index - 1)
					}, label: {
						Image("icon_previous")
							.renderingMode(Image.TemplateRenderingMode?.init(Image.TemplateRenderingMode.original))
							.imageScale(.large)
					})
					.padding()

                    PageView(pages: [DataInputView(),
                                     DataInputView(),
                                     DataInputView(),
                                     DataInputView()], currentPage: $index)

					Button(action: {
						self.index = (self.index == 3) ? self.index : (self.index + 1)
					}, label: {
						Image("icon_next")
							.renderingMode(Image.TemplateRenderingMode?.init(Image.TemplateRenderingMode.original))
							.imageScale(.large)
					})
					.padding()
				}

				PageControlView(numberOfPages: 4, currentTab: $index)
					.padding(.bottom, 20)
			}
			.navigationBarItems(trailing: self.createNavigationBarItems())
			.alert(isPresented: $showFirstAlert) {
				// This alert never shows
				Alert(title: Text("First Alert"), message: Text("This is the first alert"))
			}
		}
		.navigationViewStyle(StackNavigationViewStyle())
    }

	func createNavigationBarItems() -> some View {
		HStack {
			Button(action: {
				self.showFirstAlert = true
			}, label: {
				Text("Upload")
			})
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
