import SwiftUI
import Observation

// 1. Khai báo ViewModel sử dụng @Observable
@Observable
final class BuggyUserViewModel {
    var name: String
    var clicks = 0

    init(name: String) {
        self.name = name
        // In ra console để theo dõi số lần ViewModel bị khởi tạo lại
        print("🔴 [Khởi tạo] BuggyUserViewModel tạo mới với tên: \(name)")
    }
}

// 2. Child View: Khởi tạo trực tiếp ViewModel không có wrapper giữ state
struct BuggyUserView: View {
    // Khai báo trực tiếp, không có @State hay @StateObject bọc bên ngoài
    var viewModel: BuggyUserViewModel

    init(name: String) {
        self.viewModel = BuggyUserViewModel(name: name)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Tên User: \(viewModel.name)")
                .font(.headline)
            
            Button("Số lần click User: \(viewModel.clicks)") {
                viewModel.clicks += 1
                print("🟢 [Click] Clicks của \(viewModel.name) hiện tại là: \(viewModel.clicks)")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

// 3. Parent View: Nơi chứa State gây ra re-render
struct ContentView: View {
    // Biến state này của Parent, không liên quan gì đến Child View
    @State private var parentValue = 0
    
    var body: some View {
        VStack(spacing: 40) {
            
            // Khu vực của Parent
            VStack {
                Text("PARENT VIEW")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Stepper("Parent Value: \(parentValue)", value: $parentValue)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // Khu vực của Child
            VStack {
                Text("CHILD VIEW")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Truyền tham số để khởi tạo Child View
                BuggyUserView(name: "Florian")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
