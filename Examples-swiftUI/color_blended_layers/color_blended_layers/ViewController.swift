//
//  ViewController.swift
//  color_blended_layers
//
//  Created by huy on 2026/03/12.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
//        example_1_NG()
//        example_1_fixed()
//        example_2_NG()
        example_2_fix()
    }

    // backgroundColor mặc nil → clear color → TRANSPARENT → ĐỎ
    func example_1_NG() {
        let label = UILabel()
        label.text = "Hello World"

        // 1. Bắt buộc: Báo cho iOS biết chúng ta sẽ tự viết Auto Layout
        label.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(label)

        // 2. Kích hoạt các constraint để căn giữa
        NSLayoutConstraint.activate([
            // Căn giữa theo chiều ngang (Trục X)
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            
            // Căn giữa theo chiều dọc (Trục Y)
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
    
    func example_1_fixed() {
        let label = UILabel()
        label.text = "Hello World"
        
        // hoặc màu nền phù hợp
        label.backgroundColor = .white
        label.isOpaque = true

        // 1. Bắt buộc: Báo cho iOS biết chúng ta sẽ tự viết Auto Layout
        label.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(label)

        // 2. Kích hoạt các constraint để căn giữa
        NSLayoutConstraint.activate([
            // Căn giữa theo chiều ngang (Trục X)
            label.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            
            // Căn giữa theo chiều dọc (Trục Y)
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
    
    func example_2_NG() {
        let imageView = UIImageView(image: UIImage(named: "avatar"))

        // 1. Bắt buộc: Tắt constraint mặc định để dùng Auto Layout code
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Tùy chọn: Chỉnh chế độ hiển thị ảnh để không bị méo tỉ lệ
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        self.view.addSubview(imageView)

        // 2. Kích hoạt các constraint
        NSLayoutConstraint.activate([
            // Căn giữa theo trục X và trục Y
            imageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            
            // (Tùy chọn) Khóa kích thước ảnh cố định
            imageView.widthAnchor.constraint(equalToConstant: 200),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    /// vấn đề nằm ở chỗ bản thân ảnh PNG vẫn chứa alpha channel
    /// nên cách fix dưới ko có tác dụng
    func example_2_fix() {
        // Lấy ảnh gốc và gọi hàm loại bỏ Alpha
        guard let originalImage = UIImage(named: "avatar") else { return }
        let opaqueImage = originalImage.removingAlpha()
        
        let imageView = UIImageView(image: opaqueImage)

        // 1. Bắt buộc: Tắt constraint mặc định để dùng Auto Layout code
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Tùy chọn: Chỉnh chế độ hiển thị ảnh để không bị méo tỉ lệ
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
        // Hoặc tốt hơn: dùng ảnh JPEG (không có alpha channel)
        imageView.isOpaque = true
        imageView.backgroundColor = .white

        self.view.addSubview(imageView)

        // 2. Kích hoạt các constraint
        NSLayoutConstraint.activate([
            // Căn giữa theo trục X và trục Y
            imageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            
            // (Tùy chọn) Khóa kích thước ảnh cố định
            imageView.widthAnchor.constraint(equalToConstant: 200),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
}

extension UIImage {
    // Hàm này sẽ loại bỏ kênh Alpha và lấp đầy nền bằng màu trắng
    func removingAlpha() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true // Ép buộc không dùng Alpha channel
        format.scale = self.scale
        
        let renderer = UIGraphicsImageRenderer(size: self.size, format: format)
        return renderer.image { context in
            // Đổ nền trắng (hoặc màu bất kỳ khớp với UI của bạn)
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: self.size))
            
            // Vẽ đè ảnh gốc lên trên
            self.draw(in: CGRect(origin: .zero, size: self.size))
        }
    }
}
