import SwiftUI

// Giả định toàn bộ file SimpleToast (SimpleToast.swift, SimpleToastOptions.swift,
// PresentationState.swift, các modifier animation...) đã ở cùng target.

struct SimpleToastDemoView: View {
    // Mỗi kiểu animation một cờ hiển thị
    @State private var showFade = false
    @State private var showSlide = false
    @State private var showScale = false
    @State private var showSkew = false

    // Toast có auto-dismiss + backdrop
    @State private var showAutoHide = false

    // Ví dụ simpleToast(item:) theo dữ liệu Identifiable
    @State private var currentMessage: ToastMessage?

    // Ví dụ nhận toast qua NotificationCenter
    @State private var notifiedMessage: ToastMessage?

    var body: some View {
        NavigationStack {
            List {
                Section("4 kiểu animation") {
                    Button("Fade")  { showFade = true }
                    Button("Slide (từ trên xuống)") { showSlide = true }
                    Button("Scale") { showScale = true }
                    Button("Skew (xoay 3D)") { showSkew = true }
                }

                Section("Tùy chọn nâng cao") {
                    Button("Auto-hide 2s + backdrop mờ") { showAutoHide = true }
                    Button("Toast theo item (dữ liệu)") {
                        currentMessage = ToastMessage(text: "Đã lưu hồ sơ", icon: "checkmark.circle.fill", color: .green)
                    }
                }

                Section("Qua NotificationCenter") {
                    Button("Publish 1 notification toast") {
                        SimpleToastNotificationPublisher.publish(
                            notification: ToastMessage(text: "Có thông báo mới!", icon: "bell.fill", color: .orange)
                        )
                    }
                }
            }
            .navigationTitle("SimpleToast Demo")
        }

        // MARK: - Fade (mặc định, canh trên)
        .simpleToast(
            isPresented: $showFade,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2)
        ) {
            toastBar(text: "Fade toast", icon: "sparkles", color: .blue)
        }

        // MARK: - Slide (trượt vào từ cạnh theo alignment)
        .simpleToast(
            isPresented: $showSlide,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2, animation: .easeInOut, modifierType: .slide)
        ) {
            toastBar(text: "Slide toast", icon: "arrow.down.circle.fill", color: .purple)
        }

        // MARK: - Scale (phóng từ nhỏ ra)
        .simpleToast(
            isPresented: $showScale,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2, animation: .spring(), modifierType: .scale)
        ) {
            toastBar(text: "Scale toast", icon: "magnifyingglass", color: .pink)
        }

        // MARK: - Skew (xoay 3D quanh cạnh trên)
        .simpleToast(
            isPresented: $showSkew,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2, animation: .linear, modifierType: .skew)
        ) {
            toastBar(text: "Skew toast", icon: "rotate.3d", color: .teal)
        }

        // MARK: - Auto-hide + backdrop + dismiss on tap
        .simpleToast(
            isPresented: $showAutoHide,
            options: SimpleToastOptions(
                alignment: .bottom,
                hideAfter: 2,
                backdrop: Color.black.opacity(0.4),
                animation: .easeInOut,
                modifierType: .slide,
                dismissOnTap: true
            )
        ) {
            toastBar(text: "Chạm nền tối hoặc chờ 2s để tắt", icon: "hand.tap.fill", color: .indigo)
        }

        // MARK: - simpleToast(item:) — hiện khi currentMessage != nil
        .simpleToast(
            item: $currentMessage,
            options: SimpleToastOptions(alignment: .top, hideAfter: 2, modifierType: .slide)
        ) { message in
            toastBar(text: message.text, icon: message.icon, color: message.color)
        }

        // MARK: - Nhận toast phát qua NotificationCenter
        .simpleToast(
            item: $notifiedMessage,
            options: SimpleToastOptions(alignment: .top, hideAfter: 3, animation: .spring(), modifierType: .scale)
        ) { message in
            toastBar(text: message.text, icon: message.icon, color: message.color)
        }
        .onToastNotification { (message: ToastMessage?) in
            notifiedMessage = message
        }
    }

    // MARK: - Giao diện một thanh toast dùng chung
    private func toastBar(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
            Text(text).font(.subheadline).bold()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Capsule().fill(color))
        .shadow(radius: 6)
        .padding(.top, 8)
    }
}

// Dữ liệu toast cho simpleToast(item:) và NotificationCenter.
// Phải Identifiable vì cả hai API đều yêu cầu.
struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let color: Color
}

#Preview {
    SimpleToastDemoView()
}
