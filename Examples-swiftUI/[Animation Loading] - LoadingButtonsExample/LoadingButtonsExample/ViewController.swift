//
//  ViewController.swift
//  LoadingButtonsExample
//
//  Created by huy on 2026/02/18.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 30
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        // 1. Button Kiểu Material (Vòng tròn xoay)
        let materialBtn = createButton(title: "Material Loader", color: .systemBlue)
        materialBtn.indicator = MaterialLoadingIndicator(color: .white) // Set kiểu indicator
        materialBtn.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        
        // 2. Button Kiểu Ball Pulse (3 chấm nhảy)
        let ballPulseBtn = createButton(title: "Ball Pulse", color: .systemPink)
        ballPulseBtn.indicator = BallPulseIndicator(color: .white)
        ballPulseBtn.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        
        // 3. Button Kiểu Line Scale (Sóng âm) + Có bóng đổ (Shadow)
        // Sử dụng init có sẵn của thư viện để set shadow và corner radius
        let shadowBtn = LoadingButton(
            text: "Shadow & Line Scale",
            textColor: .white,
            bgColor: .systemPurple,
            cornerRadius: 25,
            withShadow: true // Bật bóng đổ
        )
        shadowBtn.indicator = LineScaleIndicator(color: .white)
        shadowBtn.contentEdgeInsets = UIEdgeInsets(top: 15, left: 30, bottom: 15, right: 30)
        shadowBtn.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        
        // 4. Button Kiểu Ball Spin Fade (Vòng tròn chấm)
        let spinBtn = createButton(title: "Ball Spin Fade", color: .systemOrange)
        spinBtn.indicator = BallSpinFadeIndicator(color: .white)
        spinBtn.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
        
        stackView.addArrangedSubview(materialBtn)
        stackView.addArrangedSubview(ballPulseBtn)
        stackView.addArrangedSubview(shadowBtn)
        stackView.addArrangedSubview(spinBtn)
    }
    
    // Helper tạo button nhanh
    private func createButton(title: String, color: UIColor) -> LoadingButton {
        let btn = LoadingButton(
            text: title,
            textColor: .white,
            bgColor: color,
            cornerRadius: 10,
            withShadow: false
        )
        // Kích thước mặc định cho đẹp
        btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return btn
    }
    
    // MARK: - Xử lý sự kiện
    @objc func handleTap(_ sender: LoadingButton) {
        
        // 1. Kiểm tra trạng thái đang load chưa
        guard !sender.isLoading else { return }
        
        print("Bắt đầu loading...")
        
        // 2. Gọi hàm showLoader
        // userInteraction: false -> chặn người dùng bấm tiếp khi đang load
        sender.showLoader(userInteraction: false) {
            // Completion block (chạy sau khi animation hiện lên xong)
            print("Loader đã hiện")
        }
        
        // 3. Giả lập gọi API mất 3 giây
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            
            // 4. Ẩn loader khi xong việc
            sender.hideLoader {
                print("Đã ẩn loader, quay về trạng thái nút bấm")
            }
        }
    }
}

