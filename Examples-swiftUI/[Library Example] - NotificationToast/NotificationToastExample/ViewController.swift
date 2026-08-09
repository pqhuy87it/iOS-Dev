//
//  ViewController.swift
//  NotificationToastExample
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
    
    // 1. Thông báo cơ bản (Chỉ có Text)
    @objc func showSimpleToast() {
        let toast = ToastView(
            title: "Đã lưu thay đổi",
            position: .top // .top hoặc .bottom
        )
        toast.show(haptic: .success) // Rung nhẹ khi hiện
    }
    
    // 2. Thông báo kiểu AirPods (Icon + Title + Subtitle)
    @objc func showAirpodsToast() {
        // Sử dụng SF Symbols cho tiện lợi
        let icon = UIImage(systemName: "airpodspro")?.withTintColor(.label, renderingMode: .alwaysOriginal)
        
        let toast = ToastView(
            title: "AirPods Pro",
            subtitle: "Đã kết nối • 80%",
            icon: icon,
            position: .top
        )
        
        // Cấu hình thêm (Optional)
        toast.displayTime = 2.0 // Hiện trong 2 giây
        toast.hideOnTap = true
        
        toast.show(haptic: .success)
    }
    
    // 3. Thông báo Tùy chỉnh (Màu sắc, Font)
    @objc func showCustomToast() {
        let icon = UIImage(systemName: "exclamationmark.triangle.fill")?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        
        let toast = ToastView(
            title: "Cảnh báo",
            titleFont: UIFont.boldSystemFont(ofSize: 14),
            subtitle: "Mất kết nối mạng",
            icon: icon,
            position: .bottom
        )
        
        // Tùy chỉnh màu nền
        toast.lightBackgroundColor = UIColor.systemGray6
        toast.darkBackgroundColor = UIColor.darkGray
        
        toast.show(haptic: .warning)
    }
    
    // MARK: - Setup UI (Bỏ qua phần này, chỉ để tạo nút bấm)
    private func setupButtons() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let btn1 = UIButton(type: .system)
        btn1.setTitle("Simple Toast", for: .normal)
        btn1.addTarget(self, action: #selector(showSimpleToast), for: .touchUpInside)
        
        let btn2 = UIButton(type: .system)
        btn2.setTitle("AirPods Style", for: .normal)
        btn2.addTarget(self, action: #selector(showAirpodsToast), for: .touchUpInside)
        
        let btn3 = UIButton(type: .system)
        btn3.setTitle("Custom Warning (Bottom)", for: .normal)
        btn3.addTarget(self, action: #selector(showCustomToast), for: .touchUpInside)
        
        stack.addArrangedSubview(btn1)
        stack.addArrangedSubview(btn2)
        stack.addArrangedSubview(btn3)
    }
}

