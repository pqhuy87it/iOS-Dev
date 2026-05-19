import SwiftUI
import Observation

// 1. Khai báo ViewModel sử dụng @Observable
@Observable
final class StateUserViewModel {
    var name: String
    var clicks = 0

    init(name: String) {
        self.name = name
        print("🔴 [Khởi tạo] StateUserViewModel tạo mới với tên: \(name)")
    }
}

// 2. Child View: Dùng @State để giữ reference của ViewModel
struct StateUserView: View {
    // Dùng @State để bọc ViewModel, giúp SwiftUI giữ lại instance này qua các lần re-render
    @State private var viewModel: StateUserViewModel

    init(name: String) {
        // Cú pháp khởi tạo @State thông qua tham số initialValue (hoặc wrappedValue)
        self._viewModel = State(initialValue: StateUserViewModel(name: name))
        print("🟡 [Init View] Child View được gọi init với tham số name = \(name)")
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Tên User hiện tại: \(viewModel.name)")
                .font(.headline)
            
            Button("Số lần click: \(viewModel.clicks)") {
                viewModel.clicks += 1
                print("🟢 [Click] Clicks của \(viewModel.name) tăng lên: \(viewModel.clicks)")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// 3. Parent View
struct ContentView: View {
    @State private var parentValue = 0
    @State private var switchUser = false // Biến dùng để đổi tên User
    
    var body: some View {
        VStack(spacing: 40) {
            
            // Khu vực của Parent
            VStack(spacing: 20) {
                Text("PARENT VIEW")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Stepper("Bấm để test Re-render: \(parentValue)", value: $parentValue)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                Toggle("Đổi tên User thành \(switchUser ? "Florian" : "Chris")", isOn: $switchUser)
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
            }
            
            // Khu vực của Child
            VStack {
                Text("CHILD VIEW")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Truyền tên xuống Child View dựa vào biến switchUser
                StateUserView(name: switchUser ? "Florian" : "Chris")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
