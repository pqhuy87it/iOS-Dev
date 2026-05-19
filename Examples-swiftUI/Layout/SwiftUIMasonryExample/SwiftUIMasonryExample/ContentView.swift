import SwiftUI

// 1. Tạo một model dữ liệu mẫu (Item) yêu cầu protocol Identifiable
struct MasonryItem: Identifiable {
    let id = UUID()
    let color: Color
    let height: CGFloat
}

struct ContentView: View {
    // 2. Khởi tạo mảng dữ liệu với chiều cao và màu sắc ngẫu nhiên để thấy rõ hiệu ứng Masonry
    let items: [MasonryItem] = (1...30).map { index in
        MasonryItem(
            color: Color(
                red: .random(in: 0.3...0.9),
                green: .random(in: 0.3...0.9),
                blue: .random(in: 0.3...0.9)
            ),
            height: CGFloat.random(in: 100...300) // Chiều cao random từ 100 đến 300
        )
    }
    
    // State để tuỳ chỉnh chế độ sắp xếp
    @State private var placementMode: MasonryPlacementMode = .fill
    
    var body: some View {
        NavigationView {
            ScrollView {
                // 3. Sử dụng VMasonry (Masonry chiều dọc)
                // - columns: .adaptive(minLength: 150) -> Tự động chia cột sao cho mỗi cột rộng tối thiểu 150pt
                // - spacing: Khoảng cách giữa các phần tử là 12pt
                // - data: truyền mảng items vào
                VMasonry(columns: .adaptive(minLength: 150), spacing: 12, data: items) { item in
                    
                    // Thiết kế giao diện cho từng phần tử (Cell)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(item.color)
                        .frame(height: item.height) // Áp dụng chiều cao ngẫu nhiên
                        .overlay(
                            Text("H: \(Int(item.height))")
                                .font(.headline)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        )
                }
                .padding()
                // Áp dụng Placement Mode từ môi trường (Environment)
                .masonryPlacementMode(placementMode)
                // Thêm animation mượt mà khi đổi mode
                .animation(.easeInOut, value: placementMode)
            }
            .navigationTitle("Khám phá Masonry")
            // Thêm thanh công cụ để người dùng chuyển đổi qua lại giữa Fill và Order
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("Placement Mode", selection: $placementMode) {
                        Text("Fill Mode").tag(MasonryPlacementMode.fill)
                        Text("Order Mode").tag(MasonryPlacementMode.order)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
