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
        setupGlobalToastConfig()
    }
    
    // Gọi hàm này 1 lần lúc app khởi động (trong AppDelegate)
    func setupGlobalToastConfig() {
        // Cấu hình style chung
        var style = ToastStyle()
        style.backgroundColor = UIColor.darkGray.withAlphaComponent(0.9)
        style.cornerRadius = 5
        
        // Áp dụng vào Manager
        ToastManager.shared.style = style
        
        // Cấu hình hành vi chung
        ToastManager.shared.isTapToDismissEnabled = true // Cho phép chạm để tắt
        ToastManager.shared.isQueueEnabled = true        // Xếp hàng (hiện lần lượt) thay vì đè lên nhau
        ToastManager.shared.duration = 4.0               // Mặc định luôn là 4 giây
        ToastManager.shared.position = .bottom           // Mặc định luôn ở dưới đáy
    }

    @IBAction func btn1Pressed(_ sender: Any) {
        showBasicToast()
    }
    
    func showBasicToast() {
            // Hiển thị ở vị trí mặc định (Bottom)
            self.view.makeToast("Đã lưu dữ liệu thành công!")
            
            // Hiển thị ở vị trí cụ thể (Top, Center, Bottom)
            self.view.makeToast("Chào mừng bạn quay lại", position: .top)
        }
    
    @IBAction func btn2Pressed(_ sender: Any) {
        showComplexToast()
    }
    
    func showComplexToast() {
        // Giả sử bạn có ảnh icon trong Assets tên là "success_icon"
        let image = UIImage(named: "success_icon")
        
        self.view.makeToast("Dữ liệu đã được đồng bộ lên máy chủ.",
                            duration: 4.0,              // Hiện trong 4 giây
                            position: .center,          // Hiện giữa màn hình
                            title: "Thành công",        // Tiêu đề đậm
                            image: image) { didTap in   // Callback khi tắt
            if didTap {
                print("Người dùng đã chạm vào Toast để tắt nó")
            } else {
                print("Toast tự động tắt sau khi hết giờ")
            }
        }
    }
    
    @IBAction func btn3Pressed(_ sender: Any) {
        fetchData()
    }
    
    func fetchData() {
        // 1. Hiển thị vòng quay loading
        // Bạn có thể chọn position: .center, .bottom, .top
        self.view.makeToastActivity(.center)
        
        // Giả lập call API mất 2 giây
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            
            // 2. Tắt vòng quay loading
            self.view.hideToastActivity()
            
            // 3. Hiện thông báo kết quả
            self.view.makeToast("Tải dữ liệu xong!")
        }
    }
    
    @IBAction func btn4Pressed(_ sender: Any) {
        showErrorToast()
    }
    
    func showErrorToast() {
        var style = ToastStyle()
        
        // Tùy chỉnh màu sắc
        style.messageColor = .white
        style.backgroundColor = .systemRed // Màu nền đỏ cho lỗi
        
        // Tùy chỉnh phông chữ
        style.messageFont = UIFont.systemFont(ofSize: 14)
        style.cornerRadius = 20
        
        // Có bật bóng đổ hay không
        style.displayShadow = true
        style.shadowColor = .black
        style.shadowOpacity = 0.5
        
        // Hiển thị với style vừa tạo
        self.view.makeToast("Đã xảy ra lỗi kết nối Internet!",
                            duration: 3.0,
                            position: .bottom,
                            style: style)
    }
    
    @IBAction func btn5Pressed(_ sender: Any) {
        showCustomViewAsToast()
    }
    
    func showCustomViewAsToast() {
        // Tạo view custom (hoặc load từ XIB)
        let customView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        customView.backgroundColor = .systemBlue
        customView.layer.cornerRadius = 25
        
        let label = UILabel(frame: customView.bounds)
        label.text = "Custom View ✨"
        label.textColor = .white
        label.textAlignment = .center
        customView.addSubview(label)
        
        // Hiển thị view đó như Toast
        self.view.showToast(customView,
                            duration: 3.0,
                            position: .top) // Hiện ở trên cùng
    }
}

