//
//  ViewController.swift
//  ClosuresExample
//
//  Created by huy on 2026/02/18.
//

import UIKit

class ViewController: UIViewController {
    
    // MARK: - Properties để test KVO
    @objc dynamic var counter: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Closures Library Demo"
        
        setupUI()
    }
    
    func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        
        // ====================================================
        // 1. UIControl (Button) - Thay thế addTarget
        // ====================================================
        let btn = UIButton(type: .system)
        btn.setTitle("Tap me (UIControl)", for: .normal)
        btn.configuration = .filled()
        
        // Cách dùng thư viện: .on(.event) { }
        btn.on(.touchUpInside) { (sender, _arg)  in
            print("Button đã được bấm! Sender: \(sender)")
            // Thay đổi biến counter để test KVO ở bước 3
            self.counter += 1
        }
        stackView.addArrangedSubview(btn)
        
        // ====================================================
        // 2. UISwitch - Xử lý Value Changed
        // ====================================================
        let toggle = UISwitch()
        
        // Cách dùng thư viện: .onChange { } (Viết tắt cho .valueChanged)
        toggle.onChange { isOn in
            print("Switch state: \(isOn ? "ON" : "OFF")")
            self.view.backgroundColor = isOn ? .systemGray6 : .systemBackground
        }
        stackView.addArrangedSubview(toggle)
        
        // ====================================================
        // 3. KVO (Key-Value Observing)
        // ====================================================
        let label = UILabel()
        label.text = "Counter: 0"
        
        // Cách dùng thư viện: observe(\.keyPath)
        // Lưu ý: Cần giữ reference tới observer nếu không muốn nó bị huỷ sớm,
        // nhưng thư viện này thường tự quản lý vòng đời theo object chủ.
        self.observe(\.counter) { old, new in
            print("KVO Triggered: \(old) -> \(new)")
            label.text = "Counter: \(new)"
            
            // Animation nhẹ để thấy rõ thay đổi
            UIView.animate(withDuration: 0.1) {
                label.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            } completion: { _ in
                label.transform = .identity
            }
        }
        stackView.addArrangedSubview(label)
        
        // ====================================================
        // 4. UIGestureRecognizer - Thao tác cử chỉ
        // ====================================================
        let gestureView = UIView()
        gestureView.backgroundColor = .systemOrange
        gestureView.layer.cornerRadius = 8
        
        let infoLabel = UILabel()
        infoLabel.text = "Tap or Pan me"
        infoLabel.textColor = .white
        gestureView.addSubview(infoLabel)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.centerXAnchor.constraint(equalTo: gestureView.centerXAnchor).isActive = true
        infoLabel.centerYAnchor.constraint(equalTo: gestureView.centerYAnchor).isActive = true
        
        stackView.addArrangedSubview(gestureView)
        gestureView.translatesAutoresizingMaskIntoConstraints = false
        gestureView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        gestureView.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        // Tap Gesture
        gestureView.addTapGesture { tapGesture in
            print("View Tapped!")
            // Đổi màu ngẫu nhiên để thấy hiệu ứng
            gestureView.backgroundColor = (gestureView.backgroundColor == .systemOrange) ? .systemRed : .systemOrange
        }
        
        // Pan Gesture (Kéo thả)
        gestureView.addPanGesture { panGesture in
            let translation = panGesture.translation(in: self.view)
            if panGesture.state == .changed {
                gestureView.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
            } else if panGesture.state == .ended {
                UIView.animate(withDuration: 0.3) {
                    gestureView.transform = .identity
                    gestureView.backgroundColor = .systemOrange
                }
            }
        }
        
        // ====================================================
        // 5. UIBarButtonItem (Navigation Bar)
        // ====================================================
        // Thay vì target: self, action: #selector(...)
        let rightItem = UIBarButtonItem(barButtonSystemItem: .refresh) {
            print("Refresh tapped via Closure!")
            // self.counter = 0 // Reset counter (đảm bảo self không bị retain cycle nếu cần)
        }
        self.navigationItem.rightBarButtonItem = rightItem
    }
    
    
}

