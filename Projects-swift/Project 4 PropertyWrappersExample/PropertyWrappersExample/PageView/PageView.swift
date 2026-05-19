
import SwiftUI

struct PageView<Page: View>: View {
	var viewControllers: [UIHostingController<Page>]
	@Binding var currentTab: Int

	init(_ views: [Page], currentTab: Binding<Int>) {
		viewControllers = views.map { UIHostingController(rootView: $0) }
		_currentTab = currentTab
	}

	var body: some View {
		ZStack(alignment: .bottomTrailing) {
			PageViewController(controllers: viewControllers, currentTab: $currentTab)
		}
	}
}
