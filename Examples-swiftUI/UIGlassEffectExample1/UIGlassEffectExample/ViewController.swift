//
//  ViewController.swift
//  UIGlassEffectExample
//
//  Created by huy on 2026/02/11.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupGlassView()
    }

    func setupGlassView() {
            // 1. Setup hình nền để thấy rõ hiệu ứng khúc xạ (refraction)
            let bgImageView = UIImageView(image: UIImage(named: "abstract_bg"))
            bgImageView.contentMode = .scaleAspectFill
            bgImageView.frame = view.bounds
            view.addSubview(bgImageView)

            // 2. Khởi tạo UIGlassEffect (API mới)
            // style: .thin, .regular, .thick, .ultraThick (tương tự Material cũ nhưng render kiểu kính)
            let glassEffect = UIGlassEffect(style: .regular)
            
            // Cấu hình thêm các thuộc tính mới của Glass Effect
            // isInteractive: Hiệu ứng kính sẽ phản hồi khi người dùng chạm hoặc vuốt qua
            glassEffect.isInteractive = true
            
            // tintColor: Ám màu nhẹ lên lớp kính (giữ độ trong suốt)
            glassEffect.tintColor = UIColor.systemBlue.withAlphaComponent(0.1)

            // 3. Đưa vào UIVisualEffectView
            let glassView = UIVisualEffectView(effect: glassEffect)
            glassView.frame = CGRect(x: 40, y: 200, width: 300, height: 200)
            
            // Bo góc: Liquid Glass yêu cầu bo góc mềm mại (continuous)
            glassView.layer.cornerRadius = 30
            glassView.layer.cornerCurve = .continuous
            glassView.clipsToBounds = true

            // 4. Thêm nội dung (Lưu ý: Luôn thêm vào contentView)
            let label = UILabel()
            label.text = "Liquid Glass UI"
            label.font = .systemFont(ofSize: 28, weight: .bold)
            label.textColor = .label // Màu động tự thích ứng
            label.sizeToFit()
            label.center = CGPoint(x: 150, y: 100)
            
            glassView.contentView.addSubview(label)
            view.addSubview(glassView)
        }
}

