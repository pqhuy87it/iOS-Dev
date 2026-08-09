//
//  MTPale.swift
//  MotionToast
//
//  Created by Sameer Nawaz on 10/08/20.
//  Copyright © 2020 Femargent Inc. All rights reserved.
//

import UIKit

class MTPale: UIView {
    
    @IBOutlet weak var headLabel: UILabel!
    @IBOutlet weak var msgLabel: UILabel!
    @IBOutlet weak var circleView: UIView!
    @IBOutlet weak var circleImg: UIImageView!
    @IBOutlet weak var toastView: UIView!
    @IBOutlet weak var sideBarView: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        sideBarView.layer.cornerRadius = 3
        toastView.layer.cornerRadius = 12
        circleView.layer.cornerRadius = circleView.bounds.size.width/2
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    func commonInit() {
        let bundle = Bundle(for: MTPale.self)
        let viewFromXib = bundle.loadNibNamed("MTPale", owner: self, options: nil)![0] as! UIView
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
        switch toastType {
            case .success:
                headLabel.text = "Success"
                circleImg.image = UIImage(systemName: "checkmark.circle.fill")
                circleImg.tintColor = .systemGreen
                let color = UIColor.systemGreen
                sideBarView.backgroundColor = color
                circleView.backgroundColor = color
                toastView.backgroundColor = color.withAlphaComponent(0.1) // Làm mờ nền
            case .error:
                headLabel.text = "Error"
                circleImg.image = UIImage(systemName: "xmark.octagon.fill")
                circleImg.tintColor = .systemRed
                let color = UIColor.systemRed
                sideBarView.backgroundColor = color
                circleView.backgroundColor = color
                toastView.backgroundColor = color.withAlphaComponent(0.1)
            case .warning:
                headLabel.text = "Warning"
                circleImg.image = UIImage(systemName: "exclamationmark.triangle.fill")
                circleImg.tintColor = .systemOrange
                let color = UIColor.systemOrange
                sideBarView.backgroundColor = color
                circleView.backgroundColor = color
                toastView.backgroundColor = color.withAlphaComponent(0.1)
            case .info:
                headLabel.text = "Info"
                circleImg.image = UIImage(systemName: "info.circle.fill")
                circleImg.tintColor = .systemBlue
                let color = UIColor.systemBlue
                sideBarView.backgroundColor = color
                circleView.backgroundColor = color
                toastView.backgroundColor = color.withAlphaComponent(0.1)
            }
            
            // Set màu chữ mặc định cho style Pale
            headLabel.textColor = .label
            msgLabel.textColor = .secondaryLabel
    }
    
    func loadImage(name: String) -> UIImage? {
        let podBundle = Bundle(for: MTPale.self)
        if let url = podBundle.url(forResource: "MotionToastView", withExtension: "bundle") {
            let bundle = Bundle(url: url)
            return UIImage(named: name, in: bundle, compatibleWith: nil)
        }
        return nil
    }
    
    func loadColor(name: String) -> UIColor? {
        let podBundle = Bundle(for: MTPale.self)
        if let url = podBundle.url(forResource: "MotionToastView", withExtension: "bundle") {
            let bundle = Bundle(url: url)
            return UIColor(named: name, in: bundle, compatibleWith: nil)
        }
        return nil
    }
}
