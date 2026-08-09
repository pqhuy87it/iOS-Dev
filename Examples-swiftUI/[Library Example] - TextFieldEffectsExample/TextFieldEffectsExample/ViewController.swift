//
//  ViewController.swift
//  TextFieldEffectsExample
//
//  Created by huy on 2026/02/18.
//

import UIKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup cơ bản cho View
        view.backgroundColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1)
        title = "TextField Effects Demo"
        
        // Tap ra ngoài để ẩn bàn phím
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        setupStackView()
    }
    
    // MARK: - Setup UI
    private func setupStackView() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 30
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        // Layout cho StackView
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            // Chiều cao ước tính cho 4 trường
            stackView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // 1. Akira Effect (Viền mở rộng)
        let akiraField = AkiraTextField(frame: .zero)
        configureField(akiraField, placeholder: "Akira Effect")
        akiraField.borderColor = .systemBlue
        akiraField.placeholderColor = .systemBlue
        akiraField.textColor = .black
        
        // 2. Hoshi Effect (Gạch chân chạy)
        let hoshiField = HoshiTextField(frame: .zero)
        configureField(hoshiField, placeholder: "Hoshi Effect")
        hoshiField.borderInactiveColor = .darkGray
        hoshiField.borderActiveColor = .systemPink
        hoshiField.placeholderColor = .darkGray
        hoshiField.textColor = .black
        
        // 3. Kaede Effect (Placeholder bên cạnh)
        let kaedeField = KaedeTextField(frame: .zero)
        configureField(kaedeField, placeholder: "Kaede Effect")
        kaedeField.foregroundColor = .systemGreen.withAlphaComponent(0.6) // Màu nền của phần placeholder
        kaedeField.placeholderColor = .white
        kaedeField.textColor = .black
        kaedeField.backgroundColor = .white // Màu nền phần nhập liệu
        
        // 4. Yoshiko Effect (Nền đổi màu & Placeholder nhảy lên)
        let yoshikoField = YoshikoTextField(frame: .zero)
        configureField(yoshikoField, placeholder: "Yoshiko Effect")
        yoshikoField.activeBorderColor = .systemOrange
        yoshikoField.inactiveBorderColor = .lightGray
        yoshikoField.activeBackgroundColor = .systemOrange.withAlphaComponent(0.1)
        yoshikoField.placeholderColor = .gray
        yoshikoField.textColor = .black
        
        // Add vào stack
        stackView.addArrangedSubview(akiraField)
        stackView.addArrangedSubview(hoshiField)
        stackView.addArrangedSubview(kaedeField)
        stackView.addArrangedSubview(yoshikoField)
    }
    
    // Helper để setup chung
    private func configureField(_ textField: UITextField, placeholder: String) {
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 18)
        
        // Padding cho nội dung text bên trong đỡ bị dính lề (tuỳ loại mà cần hay không)
        // Một số effect trong thư viện này đã tự handle padding
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
}

