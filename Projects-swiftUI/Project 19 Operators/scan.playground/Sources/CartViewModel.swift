import Combine
import Foundation

// 1. Bổ sung model Product (Cần Identifiable để có id so sánh khi remove)
public struct Product: Identifiable, Equatable {
    public let id = UUID()
    // Phải thêm public cho các biến nếu muốn đọc tên/giá ở trang ngoài
    public let name: String
    public let price: Double
    
    // BẮT BUỘC: Tự viết hàm khởi tạo public cho Struct
    public init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}

// 2. Định nghĩa các Action
public enum CartAction {
    case add(Product)
    case remove(Product)
    case clear
}

// 3. ViewModel quản lý logic
public class CartViewModel: ObservableObject {
    // Thêm public để bên ngoài có thể lắng nghe sự thay đổi
    @Published public var items: [Product] = []
    @Published public var total: Double = 0
    
    // Thêm public để bên ngoài có thể gọi viewModel.action.send(...)
    public let action = PassthroughSubject<CartAction, Never>()
    
    // Thêm public để trang ngoài có thể lưu .store(in: &viewModel.subscriptions)
    public var subscriptions = Set<AnyCancellable>()
    
    public init() {
        action
            // .scan nhận vào 2 tham số:
            // 1. Giá trị khởi tạo: Một mảng rỗng [Product]()
            // 2. Closure xử lý: Lấy 'giỏ hàng hiện tại' (cart) và 'hành động mới' (action) để tạo ra giỏ hàng mới
            .scan([Product]()) { cart, action -> [Product] in
                var updated = cart
                switch action {
                case .add(let product):
                    updated.append(product)
                case .remove(let product):
                    updated.removeAll { $0.id == product.id }
                case .clear:
                    updated.removeAll()
                }
                return updated // Trả về giỏ hàng mới để .scan lưu lại cho lần tiếp theo
            }
            // handleEvents giúp ta 'nghe lén' luồng dữ liệu đi qua để cập nhật biến total
            .handleEvents(receiveOutput: { [weak self] items in
                self?.total = items.reduce(0) { $0 + $1.price }
            })
            // Gán thẳng mảng sau khi xử lý vào property @Published items
            .assign(to: &$items)
    }
}
