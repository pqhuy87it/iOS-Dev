import SwiftUI
import Observation

// 1. ViewModel cơ bản (Không cần Protocol phức tạp)
@Observable
final class SimpleUserViewModel {
    var name: String
    var clicks = 0

    init(name: String) {
        self.name = name
    }
}

// 2. Child View đơn giản: Nhận reference từ bên ngoài truyền vào
struct SimpleUserView: View {
    // Chỉ nhận giá trị, không tự khởi tạo, không cần @State
    var viewModel: SimpleUserViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Tên User hiện tại: \(viewModel.name)")
            Button("Số lần click: \(viewModel.clicks)") {
                viewModel.clicks += 1
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// 3. Parent View (Nơi quản lý toàn bộ State)
struct ContentView: View {
    @State private var parentValue = 0
    @State private var switchUser = false
    
    // TẠO SẴN 2 VIEW MODEL Ở PARENT
    @State private var chrisVM = SimpleUserViewModel(name: "Chris")
    @State private var florianVM = SimpleUserViewModel(name: "Florian")
    
    var body: some View {
        VStack(spacing: 40) {
            VStack {
                Stepper("Bấm để test Re-render: \(parentValue)", value: $parentValue)
                Toggle("Đổi sang \(switchUser ? "Chris" : "Florian")", isOn: $switchUser)
            }
            
            VStack {
                // Truyền ViewModel tương ứng dựa vào Toggle
                SimpleUserView(viewModel: switchUser ? florianVM : chrisVM)
            }
        }
        .padding()
    }
}
