//
//  ContentView.swift
//  BottomMenuExample
//
//  Created by huy on 2026/03/29.
//

import SwiftUI

// Thêm màu mặc định để fix lỗi thiếu Color.steam_background trong code của bạn
extension Color {
    static let steam_background = Color(UIColor.systemGray6)
}

// MARK: - Màn hình chính sử dụng BottomMenu
struct ContentView: View {
    // 1. Biến trạng thái để điều khiển ẩn/hiện menu
    @State private var showMenu = false
    
    var body: some View {
        // 2. Bắt buộc dùng ZStack để BottomMenu nổi lên trên nội dung chính
        ZStack(alignment: .bottom) {
            
            // --- NỘI DUNG MÀN HÌNH CHÍNH ---
            VStack(spacing: 30) {
                Text("Trang Chủ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button(action: {
                    // Mở menu khi bấm nút
                    withAnimation {
                        showMenu = true
                    }
                }) {
                    Text("Hiển thị Bottom Menu")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 250)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Nếu menu đang mở, bạn có thể làm mờ nhẹ màn hình chính (tùy chọn)
            .opacity(showMenu ? 0.3 : 1.0)
            .animation(.easeInOut, value: showMenu)
            
            // --- GỌI BOTTOM MENU Ở ĐÂY ---
            BottomMenu(
                isPresented: $showMenu,
                onDismiss: {
                    // 3. Hàm này được gọi khi người dùng vuốt menu xuống quá giới hạn
                    withAnimation {
                        self.showMenu = false
                    }
                }
            ) {
                // 4. Thiết kế giao diện bên trong Bottom Menu
                VStack(spacing: 20) {
                    // Thanh gạt nhỏ ở trên cùng (UI hint cho biết có thể vuốt)
                    Capsule()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 50, height: 5)
                        .padding(.top, 10)
                    
                    Text("Tùy chọn Menu")
                        .font(.headline)
                    
                    Button("Thêm vào giỏ hàng") {
                        print("Đã thêm!")
                        withAnimation { showMenu = false } // Bấm xong tự đóng menu
                    }
                    
                    Divider().padding(.horizontal)
                    
                    Button("Xóa sản phẩm") {
                        print("Đã xóa!")
                        withAnimation { showMenu = false }
                    }
                    .foregroundColor(.red)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: 150) // Chiều cao bằng defaultHeight của bạn
            }
        }
        .edgesIgnoringSafeArea(.bottom) // Cho phép menu kéo dài sát viền dưới màn hình
    }
}

// MARK: - Code BottomMenu của bạn (giữ nguyên logic)
struct BottomMenu<Content>: View where Content: View {
    
    enum DragState {
        case inactive
        case dragging(translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive:
                return .zero
            case .dragging(let translation):
                return translation
            }
        }
        var isDragging: Bool {
            switch self {
            case .inactive:
                return false
            case .dragging:
                return true
            }
        }
    }
    
    var isPresented: Binding<Bool>
    let content: () -> Content
    let onDismiss: () -> Void
    var defaultHeight: CGFloat = 150
    
    @GestureState private var dragState = DragState.inactive
    
    init(isPresented: Binding<Bool>,
         onDismiss: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content){
        self.content = content
        self.isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    func currentYOffset(geometry: GeometryProxy) -> CGFloat {
        if isPresented.wrappedValue && dragState.isDragging {
            return geometry.frame(in: .local).maxY - defaultHeight + dragState.translation.height * 0.5
        } else if isPresented.wrappedValue {
            return geometry.frame(in: .local).maxY - defaultHeight
        }
        return geometry.frame(in: .local).maxY + defaultHeight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                VStack {
                    self.content()
                }
            }
            .background(Color.steam_background)
            .cornerRadius(10)
            .offset(x: 0, y: self.currentYOffset(geometry: geometry))
                .gesture(DragGesture().updating(self.$dragState) { drag, state, transaction in
                    state = .dragging(translation: drag.translation)
                }.onEnded { drag in
                    if drag.predictedEndLocation.y > geometry.frame(in: .global).maxY {
                        self.onDismiss()
                    }
                })
            .animation(.spring())
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
