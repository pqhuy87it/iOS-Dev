//
//  ToastView+SwiftUI.swift
//  NotificationToast
//
//  Created by Philippe Weidmann on 20.01.2025.
//

import Foundation
import SwiftUI

@available(iOS 14.0, *)
public extension View {
    func toast(
        isPresented: Binding<Bool>,
        title: String,
        titleFont: UIFont = .systemFont(ofSize: 13, weight: .regular),
        subtitle: String? = nil,
        subtitleFont: UIFont = .systemFont(ofSize: 11, weight: .light),
        icon: UIImage? = nil,
        iconSpacing: CGFloat = 16,
        position: ToastView.Position = .top,
        haptic: UINotificationFeedbackGenerator.FeedbackType? = nil,
        onTap: (() -> Void)? = nil
    ) -> some View {
        modifier(
            ToastViewModifier(
                isPresented: isPresented,
                title: title,
                titleFont: titleFont,
                subtitle: subtitle,
                subtitleFont: subtitleFont,
                icon: icon,
                iconSpacing: iconSpacing,
                position: position,
                haptic: haptic,
                onTap: onTap
            )
        )
    }
}

@available(iOS 14.0, *)
struct ToastViewModifier: ViewModifier {
    @State private var toastView: ToastView?
    @Binding var isPresented: Bool

    let title: String
    var titleFont: UIFont = .systemFont(ofSize: 13, weight: .regular)
    let subtitle: String?
    var subtitleFont: UIFont = .systemFont(ofSize: 11, weight: .light)
    let icon: UIImage?
    var iconSpacing: CGFloat = 16
    var position: ToastView.Position = .top
    var haptic: UINotificationFeedbackGenerator.FeedbackType? = nil
    var onTap: (() -> Void)? = nil

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { isPresented in
                if isPresented {
                    let toastView = ToastView(
                        title: title,
                        titleFont: titleFont,
                        subtitle: subtitle,
                        subtitleFont: subtitleFont,
                        icon: icon,
                        iconSpacing: iconSpacing,
                        position: position,
                        onTap: onTap
                    )
                    self.toastView = toastView
                    toastView.show(haptic: haptic) {
                        self.isPresented = false
                    }
                } else {
                    toastView?.hide()
                }
            }
    }
}

@available(iOS 17.0, *)
#Preview {
    @Previewable @State var isPresented = false

    Button("Present toast") {
        isPresented = true
    }
    .toast(isPresented: $isPresented, title: "AirPods Pro", subtitle: "Connected", icon: UIImage(systemName: "airpodspro"))
}
