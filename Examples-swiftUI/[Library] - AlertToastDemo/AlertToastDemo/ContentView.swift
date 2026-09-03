import SwiftUI

// Giả định 3 file AlertToast.swift, BlurView.swift, ActivityIndicator.swift
// đã nằm cùng project/target.

struct AlertToastDemoView: View {
    // Mỗi kiểu toast một cờ hiển thị riêng
    @State private var showHUDComplete = false
    @State private var showHUDError = false
    @State private var showAlertComplete = false
    @State private var showAlertLoading = false
    @State private var showBannerSlide = false
    @State private var showBannerPop = false
    @State private var showSystemImage = false
    @State private var showRegular = false
    @State private var showCustomStyle = false

    // Ví dụ dùng .toast(item:) với dữ liệu Identifiable
    @State private var selectedTask: DemoTask?

    // Loading tự tắt sau vài giây
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                Section("HUD (nổi từ trên xuống)") {
                    Button("HUD · Complete") { showHUDComplete = true }
                    Button("HUD · Error") { showHUDError = true }
                }

                Section("Alert (giữa màn hình)") {
                    Button("Alert · Complete") { showAlertComplete = true }
                    Button("Alert · Loading (giả lập lưu 2.5s)") { startSaving() }
                }

                Section("Banner (trượt từ dưới lên)") {
                    Button("Banner · Slide") { showBannerSlide = true }
                    Button("Banner · Pop") { showBannerPop = true }
                }

                Section("Kiểu icon & nội dung khác") {
                    Button("System image (SF Symbol)") { showSystemImage = true }
                    Button("Regular (chỉ chữ, không icon)") { showRegular = true }
                    Button("Custom style (màu + font riêng)") { showCustomStyle = true }
                }

                Section("toast(item:) — theo dữ liệu Identifiable") {
                    Button("Chọn task 'Deploy'") {
                        selectedTask = DemoTask(name: "Deploy build lên TestFlight")
                    }
                }
            }
            .navigationTitle("AlertToast Demo")
        }

        // MARK: - Gắn các toast

        // HUD
        .toast(isPresenting: $showHUDComplete) {
            AlertToast(displayMode: .hud, type: .complete(.green), title: "Đã lưu")
        }
        .toast(isPresenting: $showHUDError) {
            AlertToast(displayMode: .hud, type: .error(.red),
                       title: "Thất bại", subTitle: "Kiểm tra kết nối mạng")
        }

        // Alert
        .toast(isPresenting: $showAlertComplete) {
            AlertToast(displayMode: .alert, type: .complete(.green), title: "Hoàn tất")
        }
        // Loading: duration 0 để không tự tắt, tự điều khiển bằng isSaving
        .toast(isPresenting: $isSaving, duration: 0, tapToDismiss: false) {
            AlertToast(displayMode: .alert, type: .loading, title: "Đang lưu…")
        }

        // Banner
        .toast(isPresenting: $showBannerSlide) {
            AlertToast(displayMode: .banner(.slide), type: .regular,
                       title: "Banner slide", subTitle: "Trượt lên từ cạnh dưới")
        }
        .toast(isPresenting: $showBannerPop) {
            AlertToast(displayMode: .banner(.pop), type: .systemImage("bell.fill", .orange),
                       title: "Banner pop", subTitle: "Bung ra tại chỗ")
        }

        // Icon / nội dung
        .toast(isPresenting: $showSystemImage) {
            AlertToast(displayMode: .hud,
                       type: .systemImage("heart.fill", .pink),
                       title: "Đã thích")
        }
        .toast(isPresenting: $showRegular) {
            AlertToast(displayMode: .hud, type: .regular, title: "Chỉ có chữ")
        }
        .toast(isPresenting: $showCustomStyle) {
            AlertToast(
                displayMode: .hud,
                type: .complete(.white),
                title: "Style tùy biến",
                subTitle: "Nền xanh, chữ trắng",
                style: .style(
                    backgroundColor: .blue,
                    titleColor: .white,
                    subTitleColor: .white.opacity(0.8),
                    titleFont: .headline,
                    subTitleFont: .caption
                )
            )
        }

        // toast(item:) — hiện khi selectedTask != nil, tự gán nil khi tắt
        .toast(item: $selectedTask) { task in
            AlertToast(displayMode: .banner(.slide),
                       type: .systemImage("paperplane.fill", .blue),
                       title: "Đang xử lý",
                       subTitle: task?.name)
        }
    }

    private func startSaving() {
        isSaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isSaving = false
            showHUDComplete = true   // xong thì báo complete
        }
    }
}

// Dữ liệu mẫu cho toast(item:)
struct DemoTask: Identifiable {
    let id = UUID()
    let name: String
}

#Preview {
    AlertToastDemoView()
}
