
import SwiftUI

struct PageControlView: UIViewRepresentable {
	var numberOfPages: Int
	@Binding var currentTab: Int
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIView(context: Context) -> UIPageControl {
		let control = UIPageControl()
		control.numberOfPages = numberOfPages
		control.pageIndicatorTintColor = UIColor.lightGray
		control.currentPageIndicatorTintColor = UIColor.darkGray
		control.addTarget(
			context.coordinator,
			action: #selector(Coordinator.updateCurrentPage(sender:)),
			for: .valueChanged
		)

		return control
	}

	func updateUIView(_ uiView: UIPageControl, context: Context) {
		uiView.currentPage = currentTab
	}

	class Coordinator: NSObject {
		var control: PageControlView

		init(_ control: PageControlView) {
			self.control = control
		}

		@objc
		func updateCurrentPage(sender: UIPageControl) {
			control.currentTab = sender.currentPage
		}
	}
}
