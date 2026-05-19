import SwiftUI
import Observation

// ==========================================
// ViewModelProtocol
// ==========================================

protocol ViewModelProtocol: AnyObject, Observable {
    associatedtype Init: Equatable
    init(_ initializer: Init)
}

class Box<Wrapped> {
    var wrapped: Wrapped
    init(_ wrapped: Wrapped) { self.wrapped = wrapped }
}

@propertyWrapper
struct ViewModel<VM: ViewModelProtocol>: DynamicProperty {
    var initializer: VM.Init
    @State private var viewModel: Box<VM?> = Box(nil)
    @State private var previousValue: Box<VM.Init?> = Box(nil)

    init(_ initializer: VM.Init) {
        self.initializer = initializer
    }

    var wrappedValue: VM { viewModel.wrapped! }
    var projectedValue: Bindable<VM> { Bindable(wrappedValue) }

    // Đây là nơi phép màu xảy ra (Được SwiftUI gọi tự động trước mỗi lần tính toán body)
    func update() {
        guard viewModel.wrapped != nil else {
            // Lần khởi tạo đầu tiên
            viewModel.wrapped = VM(initializer)
            previousValue.wrapped = initializer
            return
        }
        
        // So sánh tham số khởi tạo mới và cũ. Nếu giống nhau thì dừng lại ngay!
        guard initializer != previousValue.wrapped else {
            return
        }
        
        // Nếu tham số thực sự đổi, khởi tạo lại ViewModel
        print("🔄 [Magic Update] Phát hiện tên đổi từ '\(previousValue.wrapped!)' sang '\(initializer)' -> Re-init ViewModel!")
        self.viewModel.wrapped = VM(initializer)
        previousValue.wrapped = initializer
    }
}

// ==========================================
// FixedUserViewModel
// ==========================================

// 1. Cập nhật ViewModel để tuân thủ ViewModelProtocol
@Observable
final class FixedUserViewModel: ViewModelProtocol {
    var name: String
    var clicks = 0

    // BẮT BUỘC CÓ: Struct Init chứa các tham số truyền từ ngoài vào
    struct Init: Equatable {
        var name: String
    }

    // BẮT BUỘC CÓ: Hàm init nhận struct Init
    init(_ initializer: Init) {
        self.name = initializer.name
        print("🔴 [Khởi tạo] FixedUserViewModel tạo mới với tên: \(self.name)")
    }
}

// 2. Child View sử dụng @ViewModel thay vì @State
struct FixedUserView: View {
    
    // Đổi @State thành @ViewModel
    @ViewModel var viewModel: FixedUserViewModel

    init(name: String) {
        // Truyền tham số thông qua cấu trúc Init của ViewModel
        self._viewModel = ViewModel(FixedUserViewModel.Init(name: name))
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
            .tint(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
}

// 3. Parent View (Giữ nguyên logic test)
struct ContentView: View {
    @State private var parentValue = 0
    @State private var switchUser = false
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Text("PARENT VIEW")
                    .font(.caption).foregroundColor(.gray)
                
                Stepper("Bấm để test Re-render: \(parentValue)", value: $parentValue)
                    .padding().background(Color.gray.opacity(0.1)).cornerRadius(12)
                
                Toggle("Đổi tên User thành \(switchUser ? "Florian" : "Chris")", isOn: $switchUser)
                    .padding().background(Color.orange.opacity(0.2)).cornerRadius(12)
            }
            
            VStack {
                Text("CHILD VIEW (ĐÃ FIX TẤT CẢ LỖI)")
                    .font(.caption).foregroundColor(.gray)
                
                FixedUserView(name: switchUser ? "Florian" : "Chris")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
