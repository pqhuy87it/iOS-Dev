import UIKit
import Combine

print("------- 1 -------")

[10, 20, 30, 40].publisher
    .scan(0) { sum, value in sum + value }
    .sink { print($0) }
// 10, 30, 60, 100

print("------- 2 -------")

["A", "B", "C", "D"].publisher
    .scan(0) { count, _ in count + 1 }
    .sink { print($0) }
// 1, 2, 3, 4

print("------- 3 -------")

[10.0, 20.0, 30.0, 40.0].publisher
    .scan((sum: 0.0, count: 0)) { state, value in
        (sum: state.sum + value, count: state.count + 1)
    }
    .map { $0.sum / Double($0.count) }
    .sink { print($0) }
// 10.0, 15.0, 20.0, 25.0

print("------- 4 -------")

[5, 3, 8, 1, 9, 2].publisher
    .scan(Int.max) { currentMin, value in min(currentMin, value) }
    .sink { print($0) }
// 5, 3, 3, 1, 1, 1

[5, 3, 8, 1, 9, 2].publisher
    .scan(Int.min) { currentMax, value in max(currentMax, value) }
    .sink { print($0) }
// 5, 5, 8, 8, 9, 9

print("------- 5: array (running) -------")

[1, 2, 3, 4].publisher
    .scan([Int]()) { array, value in array + [value] }
    .sink { print($0) }
// [1]
// [1, 2]
// [1, 2, 3]
// [1, 2, 3, 4]

print("------- 5: String concatenation -------")

["Hello", " ", "World", "!"].publisher
    .scan("") { accumulated, word in accumulated + word }
    .sink { print($0) }
// "Hello"
// "Hello "
// "Hello World"
// "Hello World!"

// ==========================================
// THỰC THI TEST TRÊN PLAYGROUND
// ==========================================

let viewModel = CartViewModel()

// Lắng nghe sự thay đổi của items và total để in ra Console
viewModel.$items
    .sink { items in
        let names = items.map { $0.name }.joined(separator: ", ")
        print("🛒 Giỏ hàng hiện tại: [\(names)]")
    }
    .store(in: &viewModel.subscriptions)

viewModel.$total
    .sink { total in
        print("💰 Tổng tiền: $\(total)\n")
    }
    .store(in: &viewModel.subscriptions)

// Khởi tạo một vài sản phẩm mẫu
let macbook = Product(name: "MacBook Pro", price: 2000)
let iphone = Product(name: "iPhone 15", price: 1000)
let airpods = Product(name: "AirPods Pro", price: 250)

// Test bắn action vào luồng
print("--- 🟢 THÊM MACBOOK ---")
viewModel.action.send(.add(macbook))

print("--- 🟢 THÊM IPHONE ---")
viewModel.action.send(.add(iphone))

print("--- 🟢 THÊM AIRPODS ---")
viewModel.action.send(.add(airpods))

print("--- 🔴 XOÁ IPHONE ---")
viewModel.action.send(.remove(iphone))

print("--- 🧹 XOÁ TOÀN BỘ GIỎ HÀNG ---")
viewModel.action.send(.clear)

