//
//  TypeSafeEventBusDemoApp.swift
//  TypeSafeEventBusDemo
//
//  Created by huy on 2026/05/17.
//

import SwiftUI
import Combine
import Observation

// MARK: - 1. Models
// Định nghĩa kiểu dữ liệu Order để đảm bảo Type-Safety
struct Order: Identifiable {
    let id = UUID()
    let title: String
    let price: Double
}

// MARK: - 2. Event Bus
// Dùng @Observable (iOS 17+) để nhúng vào Environment dễ dàng
@Observable
final class AppEventBus {
    // PassthroughSubject: Phát sự kiện đi và "quên" luôn, không lưu lại trạng thái (như @Published hay CurrentValueSubject).
    let purchaseCompleted = PassthroughSubject<Order, Never>()
    let userLoggedOut = PassthroughSubject<Void, Never>()
    let cartCleared = PassthroughSubject<Void, Never>()
}

// MARK: - 3. App Root
@main
struct TypeSafeEventBusDemoApp: App {
    // Khởi tạo Bus duy nhất cho toàn App
    @State private var bus = AppEventBus()
    
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(bus) // Bơm vào Environment để mọi View con đều dùng được
        }
    }
}

// MARK: - 4. Tab View (Nơi chứa các màn hình)
struct RootTabView: View {
    var body: some View {
        TabView {
            CheckoutView()
                .tabItem {
                    Label("Thanh toán", systemImage: "cart")
                }
            
            OrdersView()
                .tabItem {
                    Label("Đơn hàng", systemImage: "list.bullet.rectangle")
                }
        }
    }
}

// MARK: - 5. SENDER (Người phát sự kiện)
struct CheckoutView: View {
    @Environment(AppEventBus.self) private var bus
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Giả lập Mua hàng")
                .font(.title2).bold()
            
            Button(action: {
                // 1. Tạo đơn hàng mới
                let newOrder = createOrder()
                
                // 2. Phát sự kiện (Type-safe: Bắt buộc phải truyền vào đúng kiểu Order)
                bus.purchaseCompleted.send(newOrder)
                
            }) {
                Text("Xác nhận Mua")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Text("Bấm mua sau đó chuyển sang Tab 'Đơn hàng' để xem kết quả.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
    
    // Helper tạo data giả
    private func createOrder() -> Order {
        let randomID = Int.random(in: 1000...9999)
        let randomPrice = Double.random(in: 10.0...99.9)
        return Order(title: "Đơn hàng #\(randomID)", price: randomPrice)
    }
}

// MARK: - 6. RECEIVER (Người nhận sự kiện)
struct OrdersView: View {
    @Environment(AppEventBus.self) private var bus
    @State private var orders: [Order] = []
    
    var body: some View {
        NavigationView {
            Group {
                if orders.isEmpty {
                    Text("Chưa có đơn hàng nào")
                        .foregroundColor(.secondary)
                } else {
                    List(orders) { order in
                        OrderRow(order: order)
                    }
                }
            }
            .navigationTitle("Lịch sử Đơn hàng")
            // Điểm ăn tiền: Lắng nghe trực tiếp từ Subject
            .onReceive(bus.purchaseCompleted) { incomingOrder in
                // Chèn thêm hiệu ứng animation để UI cập nhật mượt mà
                withAnimation {
                    orders.insert(incomingOrder, at: 0)
                }
                print("📥 Đã nhận đơn hàng: \(incomingOrder.title)")
            }
        }
    }
}

// Helper View để vẽ từng dòng
struct OrderRow: View {
    let order: Order
    
    var body: some View {
        HStack {
            Text(order.title)
                .font(.headline)
            Spacer()
            Text(String(format: "$%.2f", order.price))
                .bold()
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}
