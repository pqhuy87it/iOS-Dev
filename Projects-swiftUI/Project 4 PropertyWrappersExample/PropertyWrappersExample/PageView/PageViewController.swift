
import SwiftUI
import UIKit

extension UIPageViewController {
	var isPagingEnabled: Bool {
		get {
			var isEnabled: Bool = true
			for view in view.subviews {
				if let subView = view as? UIScrollView {
					isEnabled = subView.isScrollEnabled
				}
			}
			return isEnabled
		}
		set {
			for view in view.subviews {
				if let subView = view as? UIScrollView {
					subView.isScrollEnabled = newValue
				}
			}
		}
	}
}

struct PageViewController: UIViewControllerRepresentable {
	var controllers: [UIViewController]
	@Binding var currentTab: Int

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIViewController(context: Context) -> UIPageViewController {
		let pageViewController = UIPageViewController(
			transitionStyle: .scroll,
			navigationOrientation: .horizontal
		)
		pageViewController.dataSource = context.coordinator
		pageViewController.delegate = context.coordinator
		pageViewController.isPagingEnabled = false

		return pageViewController
	}

	func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
		pageViewController.setViewControllers(
			[controllers[currentTab]], direction: .forward, animated: true
		)
	}

	class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
		var parent: PageViewController

		init(_ pageViewController: PageViewController) {
			parent = pageViewController
		}

		func pageViewController(
			_ pageViewController: UIPageViewController,
			viewControllerBefore viewController: UIViewController
		) -> UIViewController? {
			guard let index = parent.controllers.firstIndex(of: viewController) else {
				return nil
			}
			if index == 0 {
				return parent.controllers.last
			}
			return parent.controllers[index - 1]
		}

		func pageViewController(
			_ pageViewController: UIPageViewController,
			viewControllerAfter viewController: UIViewController
		) -> UIViewController? {
			guard let index = parent.controllers.firstIndex(of: viewController) else {
				return nil
			}
			if index + 1 == parent.controllers.count {
				return parent.controllers.first
			}
			return parent.controllers[index + 1]
		}

		func pageViewController(
			_ pageViewController: UIPageViewController,
			didFinishAnimating finished: Bool,
			previousViewControllers: [UIViewController],
			transitionCompleted completed: Bool
		) {
			if completed {
				if let visibleViewController = pageViewController.viewControllers?.first {
					if let index = parent.controllers.firstIndex(of: visibleViewController) {
						parent.currentTab = index
					}
				}
			}
		}
	}
}
