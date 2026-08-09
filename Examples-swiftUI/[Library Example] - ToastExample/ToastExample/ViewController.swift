//
//  ViewController.swift
//  ToastExample
//
//  Created by huy on 2026/02/12.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        view.backgroundColor = .systemBackground
        setupButtons()
    }
    
    // MARK: - Actions
    
    @objc func handleSimpleToast() {
        let toast = Toast.text("Lưu thành công!")
        toast.show()
    }
    
    @objc func handleIconToast() {
        // Dùng SF Symbols
        guard let image = UIImage(systemName: "star.fill") else { return }
        
        let toast = Toast.default(
            image: image,
            imageTint: .systemYellow,
            title: "Yêu thích",
            subtitle: "Đã thêm vào danh sách yêu thích."
        )
        toast.show(haptic: .success, after: 0) // Có rung phản hồi haptic
    }
    
    @objc func handleCustomTopToast() {
        // Cấu hình hiển thị ở trên cùng (Top)
        let config = ToastConfiguration(
            direction: .top,
            dismissBy: [.time(time: 3.0), .swipe(direction: .toTop)],
            animationTime: 0.3
        )
        
        let viewConfig = ToastViewConfiguration(
            darkBackgroundColor: .systemBlue,
            lightBackgroundColor: .systemBlue,
            cornerRadius: 20
        )
        
        let toast = Toast.text(
            "Thông báo mới",
            subtitle: "Bạn có 3 tin nhắn chưa đọc",
            viewConfig: viewConfig,
            config: config
        )
        toast.show()
    }
    
    // MARK: - UI Setup (Không quan trọng, chỉ để tạo nút bấm test)
    func setupButtons() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let btn1 = createButton(title: "Simple Text", action: #selector(handleSimpleToast))
        let btn2 = createButton(title: "With Icon", action: #selector(handleIconToast))
        let btn3 = createButton(title: "Custom Top (Blue)", action: #selector(handleCustomTopToast))
        
        stack.addArrangedSubview(btn1)
        stack.addArrangedSubview(btn2)
        stack.addArrangedSubview(btn3)
    }
    
    func createButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.configuration = .filled()
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
}

