//
//  ViewController.swift
//  PageboyExample
//
//  Created by huy on 2026/02/12.
//

import UIKit

class ViewController: PageboyViewController, PageboyViewControllerDataSource, PageboyViewControllerDelegate {
    func pageboyViewController(_ pageboyViewController: PageboyViewController, didReloadWith currentViewController: UIViewController, currentPageIndex: PageboyViewController.PageIndex) {
        
    }
    
    // Danh sách các view controllers sẽ hiển thị
        private let viewControllers: [UIViewController] = {
            let vc1 = ChildViewController()
            vc1.index = 0
            let vc2 = ChildViewController()
            vc2.index = 1
            let vc3 = ChildViewController()
            vc3.index = 2
            return [vc1, vc2, vc3]
        }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // 1. Gán DataSource và Delegate
                self.dataSource = self
                self.delegate = self

                // 2. Cấu hình các tùy chọn (Dựa trên source code đã cung cấp)
                self.isInfiniteScrollEnabled = true // Cho phép cuộn vô tận
                self.interPageSpacing = 10.0        // Khoảng cách giữa các trang
                
                // 3. Cấu hình tự động cuộn (Auto Scroller)
                self.autoScroller.enable(withIntermissionDuration: .custom(duration: 3.0)) // Cuộn sau mỗi 3 giây
    }

    // MARK: - PageboyViewControllerDataSource
        
        func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
            return viewControllers.count
        }

        func viewController(for pageboyViewController: PageboyViewController, at index: PageboyViewController.PageIndex) -> UIViewController? {
            return viewControllers[index]
        }

        func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
            return .first
        }

        // MARK: - PageboyViewControllerDelegate
        
        func pageboyViewController(_ pageboyViewController: PageboyViewController,
                                   willScrollToPageAt index: PageboyViewController.PageIndex,
                                   direction: PageboyViewController.NavigationDirection,
                                   animated: Bool) {
            print("Đã chuyển đến trang: \(index)")
        }
    
    func pageboyViewController(_ pageboyViewController: PageboyViewController,
                               didScrollToPageAt index: PageboyViewController.PageIndex,
                               direction: PageboyViewController.NavigationDirection,
                               animated: Bool) {
        
    }
        
        func pageboyViewController(_ pageboyViewController: PageboyViewController,
                                   didScrollTo position: CGPoint,
                                   direction: PageboyViewController.NavigationDirection,
                                   animated: Bool) {
            // Theo dõi vị trí cuộn chi tiết (ví dụ: 0.5 là đang ở giữa trang 0 và 1)
            // print("Vị trí hiện tại: \(position.x)")
        }

}

class ChildViewController: UIViewController {
    var index: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Thiết lập giao diện để phân biệt các trang
        view.backgroundColor = index % 2 == 0 ? .systemBlue : .systemTeal
        
        let label = UILabel()
        label.text = "Trang số \(index)"
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
