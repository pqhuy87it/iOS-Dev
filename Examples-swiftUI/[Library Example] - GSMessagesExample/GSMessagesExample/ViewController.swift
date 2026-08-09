//
//  ViewController.swift
//  GSMessagesExample
//
//  Created by huy on 2026/02/12.
//

import UIKit

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "GSMessage Demo"
        
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
        
        // Tạo các nút demo
        let btnSuccess = createButton(title: "Success (Top)", color: .systemGreen, action: #selector(showSuccess))
        let btnError = createButton(title: "Error (Bottom)", color: .systemRed, action: #selector(showError))
        let btnWarning = createButton(title: "Warning (Custom)", color: .systemOrange, action: #selector(showWarning))
        let btnInfo = createButton(title: "Info (Inside View)", color: .systemBlue, action: #selector(showInfoInView))
        
        stackView.addArrangedSubview(btnSuccess)
        stackView.addArrangedSubview(btnError)
        stackView.addArrangedSubview(btnWarning)
        stackView.addArrangedSubview(btnInfo)
    }
    
    private func createButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        return button
    }
    
    // MARK: - Demo Actions
    
    // 1. Thông báo Success cơ bản
    @objc func showSuccess() {
        showMessage("Lưu dữ liệu thành công!", type: .success)
    }
    
    // 2. Thông báo Error ở dưới đáy (Bottom)
    @objc func showError() {
        showMessage("Kết nối thất bại! Vui lòng kiểm tra lại mạng.",
                    type: .error,
                    options: [
                        .position(.bottom),         // Hiện ở dưới
                        .textNumberOfLines(2),      // Cho phép nhiều dòng
                        .cornerRadius(10),          // Bo góc
                        .margin(.init(top: 0, left: 20, bottom: 20, right: 20)) // Cách lề
                    ])
    }
    
    // 3. Thông báo Warning với nhiều tùy chỉnh (Animations, Font, Height)
    @objc func showWarning() {
        showMessage("Cảnh báo: Pin yếu (Dưới 20%)",
                    type: .warning,
                    options: [
                        .textAlignment(.left),              // Canh trái
                        .height(60),                        // Chiều cao cố định
                        .animationDuration(0.3),            // Thời gian animation
                        .autoHideDelay(5.0),                // Tự tắt sau 5s
                        .hideOnTap(true)                    // Chạm vào để tắt ngay
                    ])
    }
    
    // 4. Thông báo Info hiển thị trong một View con cụ thể (Không phải toàn màn hình)
    @objc func showInfoInView() {
        // Tạo một view con giả lập
        let containerView = UIView()
        containerView.backgroundColor = .systemGray6
        containerView.frame = CGRect(x: 50, y: 100, width: view.frame.width - 100, height: 150)
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true // Quan trọng để message không bị tràn ra ngoài
        
        // Add vào màn hình để demo
        view.addSubview(containerView)
        
        // Hiển thị message chỉ nằm trong view này
        containerView.showMessage("Đang tải dữ liệu...",
                                  type: .info,
                                  options: [
                                    .position(.top),
                                    .textAlignment(.center)
                                  ])
        
        // Xóa view demo sau 3 giây
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            containerView.removeFromSuperview()
        }
    }
}

