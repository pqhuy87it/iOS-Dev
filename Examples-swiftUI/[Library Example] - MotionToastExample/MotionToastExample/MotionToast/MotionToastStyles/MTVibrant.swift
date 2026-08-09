//
//  MotionToastView.swift
//  MotionToast
//
//  Created by Sameer Nawaz on 10/08/20.
//  Copyright © 2020 Femargent Inc. All rights reserved.
//

import UIKit

class MTVibrant: UIView {
    
    @IBOutlet weak var headLabel: UILabel!
    @IBOutlet weak var msgLabel: UILabel!
    @IBOutlet weak var circleImg: UIImageView!
    @IBOutlet weak var toastView: UIView!
    @IBOutlet weak var circleView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        circleView.layer.cornerRadius = circleView.bounds.size.width/2
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit() {
        let bundle = Bundle(for: MTVibrant.self)
        let viewFromXib = bundle.loadNibNamed("MTVibrant", owner: self, options: nil)![0] as! UIView
        viewFromXib.frame = self.bounds
        addSubview(viewFromXib)
    }
    
    func addPulseEffect() {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1
        pulseAnimation.fromValue = 0.7
        pulseAnimation.toValue = 1
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .greatestFiniteMagnitude
        circleImg.layer.add(pulseAnimation, forKey: "animateOpacity")
    }
    
    func setupViews(toastType: ToastType) {
        // Sửa lại dùng System Colors và SF Symbols để chạy ngay không cần Assets
            switch toastType {
            case .success:
                headLabel.text = "Success"
                headLabel.textColor = .white
                circleImg.image = UIImage(systemName: "checkmark.circle.fill") // SF Symbol
                circleImg.tintColor = .systemGreen // Tint màu cho icon
                toastView.backgroundColor = .systemGreen
            case .error:
                headLabel.text = "Error"
                headLabel.textColor = .white
                circleImg.image = UIImage(systemName: "xmark.octagon.fill")
                circleImg.tintColor = .systemRed
                toastView.backgroundColor = .systemRed
            case .warning:
                headLabel.text = "Warning"
                headLabel.textColor = .white
                circleImg.image = UIImage(systemName: "exclamationmark.triangle.fill")
                circleImg.tintColor = .systemOrange
                toastView.backgroundColor = .systemOrange
            case .info:
                headLabel.text = "Info"
                headLabel.textColor = .white
                circleImg.image = UIImage(systemName: "info.circle.fill")
                circleImg.tintColor = .systemBlue
                toastView.backgroundColor = .systemBlue
            }
            // Đảm bảo icon hiển thị đúng màu tint
            circleImg.contentMode = .scaleAspectFit
    }
    
    func loadImage(name: String) -> UIImage? {
        let podBundle = Bundle(for: MTVibrant.self)
        if let url = podBundle.url(forResource: "MotionToastView", withExtension: "bundle") {
            let bundle = Bundle(url: url)
            return UIImage(named: name, in: bundle, compatibleWith: nil)
        }
        return nil
    }
    
    func loadColor(name: String) -> UIColor? {
        let podBundle = Bundle(for: MTVibrant.self)
        if let url = podBundle.url(forResource: "MotionToastView", withExtension: "bundle") {
            let bundle = Bundle(url: url)
            return UIColor(named: name, in: bundle, compatibleWith: nil)
        }
        return nil
    }
}
