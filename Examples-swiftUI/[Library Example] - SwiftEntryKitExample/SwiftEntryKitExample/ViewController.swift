//
//  ViewController.swift
//  SwiftEntryKitExample
//
//  Created by huy on 2026/02/12.
//

public import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func btn1Pressed(_ sender: Any) {
        showSuccessMessage()
    }
    
    @IBAction func btn2Pressed(_ sender: Any) {
        showConfirmationAlert()
    }
    
    @IBAction func btn3Pressed(_ sender: Any) {
        showCustomView()
    }
    
    func showSuccessMessage() {
        // 1. Cấu hình Attributes (Vị trí, Animation, Màu sắc)
        var attributes = EKAttributes.topToast // Sử dụng preset có sẵn cho nhanh
        attributes.entryBackground = .color(color: EKColor(UIColor.systemGreen)) // Màu nền xanh
        attributes.popBehavior = .animated(animation: .init(translate: .init(duration: 0.3), scale: .init(from: 1, to: 0.7, duration: 0.7)))
        attributes.shadow = .active(with: .init(color: .black, opacity: 0.5, radius: 10, offset: .zero))
        attributes.statusBar = .dark // Giữ status bar màu tối
        attributes.displayDuration = 2 // Hiển thị trong 2 giây
        
        // 2. Cấu hình nội dung (Title, Description, Image)
        let title = EKProperty.LabelContent(
            text: "Thành công!",
            style: .init(font: UIFont.boldSystemFont(ofSize: 16), color: EKColor(.white))
        )
        let description = EKProperty.LabelContent(
            text: "Dữ liệu của bạn đã được lưu vào hệ thống.",
            style: .init(font: UIFont.systemFont(ofSize: 14), color: EKColor(.white))
        )
        let image = EKProperty.ImageContent(
            image: UIImage(systemName: "checkmark.circle.fill") ?? UIImage(),
            size: CGSize(width: 35, height: 35),
            tint: EKColor(.white)
        )
        
        let simpleMessage = EKSimpleMessage(image: image, title: title, description: description)
        
        // 3. Tạo View từ Message
        let notificationMessage = EKNotificationMessage(simpleMessage: simpleMessage)
        let contentView = EKNotificationMessageView(with: notificationMessage)
        
        // 4. Hiển thị
        SwiftEntryKit.display(entry: contentView, using: attributes)
    }
    
    func showConfirmationAlert() {
        // 1. Cấu hình Attributes
        var attributes = EKAttributes.centerFloat
        attributes.windowLevel = .alerts
        attributes.displayDuration = .infinity // Không tự tắt
        attributes.screenBackground = .color(color: EKColor(UIColor.black.withAlphaComponent(0.5))) // Làm tối màn hình nền
        attributes.entryBackground = .color(color: EKColor(.white))
        attributes.screenInteraction = .absorbTouches // Chặn touch ra ngoài
        attributes.entryInteraction = .absorbTouches
        attributes.roundCorners = .all(radius: 20)
        
        // Animation bật ra (Pop up)
        attributes.entranceAnimation = .init(
            translate: .init(duration: 0.5, anchorPosition: .bottom, spring: .init(damping: 1, initialVelocity: 0)),
            scale: .init(from: 0.6, to: 1, duration: 0.5, spring: .init(damping: 0.8, initialVelocity: 0))
        )
        
        // 2. Nội dung thông báo
        let title = EKProperty.LabelContent(
            text: "Xoá dữ liệu?",
            style: .init(font: UIFont.boldSystemFont(ofSize: 18), color: EKColor(.black), alignment: .center)
        )
        let description = EKProperty.LabelContent(
            text: "Hành động này không thể hoàn tác. Bạn có chắc chắn không?",
            style: .init(font: UIFont.systemFont(ofSize: 14), color: EKColor(.gray), alignment: .center)
        )
        let image = EKProperty.ImageContent(
            image: UIImage(systemName: "trash.circle.fill") ?? UIImage(),
            size: CGSize(width: 50, height: 50),
            tint: EKColor(.systemRed)
        )
        
        let simpleMessage = EKSimpleMessage(image: image, title: title, description: description)
        
        // 3. Cấu hình nút bấm
        let buttonLabelStyle = EKProperty.LabelStyle(font: UIFont.boldSystemFont(ofSize: 16), color: EKColor(.white))
        
        // Nút OK
        let okButton = EKProperty.ButtonContent(
            label: .init(text: "Xoá ngay", style: buttonLabelStyle),
            backgroundColor: EKColor(.systemRed),
            highlightedBackgroundColor: EKColor(.red.withAlphaComponent(0.8))
        ) {
            print("User đã bấm Xoá")
            SwiftEntryKit.dismiss() // Tắt popup
        }
        
        // Nút Cancel
        let cancelButton = EKProperty.ButtonContent(
            label: .init(text: "Huỷ", style: .init(font: UIFont.systemFont(ofSize: 16), color: EKColor(.gray))),
            backgroundColor: EKColor(.systemGray6),
            highlightedBackgroundColor: EKColor(.systemGray5)
        ) {
            SwiftEntryKit.dismiss()
        }
        
        let buttonsBarContent = EKProperty.ButtonBarContent(
            with: okButton, cancelButton,
            separatorColor: EKColor(.clear),
            buttonHeight: 50,
            expandAnimatedly: true
        )
        
        // 4. Tạo View và Hiển thị
        let alertMessage = EKAlertMessage(simpleMessage: simpleMessage, imagePosition: .top, buttonBarContent: buttonsBarContent)
        let contentView = EKAlertMessageView(with: alertMessage)
        
        SwiftEntryKit.display(entry: contentView, using: attributes)
    }
    
    func showCustomView() {
        // 1. Tạo View Custom của bạn
        let myCustomView = UIView()
        myCustomView.backgroundColor = .systemBlue
        myCustomView.layer.cornerRadius = 10
        
        let label = UILabel()
        label.text = "Đây là Custom View!"
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        myCustomView.addSubview(label)
        
        // Layout cho view (SwiftEntryKit cần biết kích thước view)
        myCustomView.translatesAutoresizingMaskIntoConstraints = false
        myCustomView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        myCustomView.widthAnchor.constraint(equalToConstant: 300).isActive = true
        
        // 2. Cấu hình Attributes
        var attributes = EKAttributes.bottomFloat // Hiện từ dưới lên
        attributes.entryBackground = .clear
        attributes.shadow = .active(with: .init(color: .black, opacity: 0.3, radius: 8))
        attributes.positionConstraints.verticalOffset = 20 // Cách đáy màn hình 20pt
        
        // 3. Hiển thị
        SwiftEntryKit.display(entry: myCustomView, using: attributes)
    }
}

