//
//  ViewController.swift
//  MotionToastExample
//
//  Created by huy on 2026/02/12.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .systemBackground
        title = "MotionToast Demo"
        
        setupButtons()
    }
    
    // MARK: - Setup UI (Tạo nút bấm)
    private func setupButtons() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let btnSuccess = createButton(title: "Success (Vibrant)", color: .systemGreen, action: #selector(showSuccessToast))
        let btnError = createButton(title: "Error (Pale)", color: .systemRed, action: #selector(showErrorToast))
        let btnWarning = createButton(title: "Warning (Top Gravity)", color: .systemOrange, action: #selector(showWarningToast))
        let btnInfo = createButton(title: "Info (Center)", color: .systemBlue, action: #selector(showInfoToast))
        let btnCustom = createButton(title: "Fully Custom", color: .purple, action: #selector(showCustomToast))
        
        stackView.addArrangedSubview(btnSuccess)
        stackView.addArrangedSubview(btnError)
        stackView.addArrangedSubview(btnWarning)
        stackView.addArrangedSubview(btnInfo)
        stackView.addArrangedSubview(btnCustom)
    }
    
    private func createButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return button
    }
    
    // MARK: - DEMO SCENARIOS
    
    // 1. Success Toast - Style Vibrant (Mặc định)
    @objc func showSuccessToast() {
        MotionToast(
            message: "Đăng nhập thành công!",
            toastType: .success,
            duration: .short,
            toastStyle: .style_vibrant,
            toastGravity: .bottom,
            toastCornerRadius: 12,
            pulseEffect: true
        )
    }
    
    // 2. Error Toast - Style Pale (Nhạt hơn)
    @objc func showErrorToast() {
        MotionToast(
            message: "Kết nối thất bại. Vui lòng thử lại.",
            toastType: .error,
            duration: .long,
            toastStyle: .style_pale, // Style nhạt
            toastGravity: .bottom,
            toastCornerRadius: 12,
            pulseEffect: true
        )
    }
    
    // 3. Warning Toast - Hiện ở trên cùng (Top)
    @objc func showWarningToast() {
        MotionToast(
            message: "Phiên đăng nhập sắp hết hạn.",
            toastType: .warning,
            duration: .short,
            toastStyle: .style_vibrant,
            toastGravity: .top, // Hiện ở trên
            toastCornerRadius: 20,
            pulseEffect: false // Tắt hiệu ứng nhịp đập
        )
    }
    
    // 4. Info Toast - Hiện ở giữa (Centre)
    @objc func showInfoToast() {
        MotionToast(
            message: "Đang tải dữ liệu mới...",
            toastType: .info,
            duration: .short,
            toastStyle: .style_pale,
            toastGravity: .centre, // Hiện ở giữa
            toastCornerRadius: 10,
            pulseEffect: true
        )
    }
    
    // 5. Custom Toast - Tùy chỉnh toàn bộ màu sắc và icon
    @objc func showCustomToast() {
        // Dùng ảnh hệ thống SF Symbols làm icon
        let icon = UIImage(systemName: "star.fill")!
        
        MotionToast_Customisation(
            header: "Thành tựu mới!",
            message: "Bạn vừa mở khóa danh hiệu Vip.",
            headerColor: .white,
            messageColor: .white,
            primary_color: .systemPurple,    // Màu nền chính
            secondary_color: .systemIndigo,  // Màu phụ (vòng tròn/cạnh bên)
            icon_image: icon,
            duration: .long,
            toastStyle: .style_vibrant,
            toastGravity: .bottom,
            toastCornerRadius: 16,
            pulseEffect: true
        )
    }
}

