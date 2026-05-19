import SwiftUI

@available(iOS 17.0, *)
struct ContainerRelativeFrameDemo: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 40) {
                
                // MARK: - Cách 1: Basic (Chiếm 100% container)
                VStack(alignment: .leading) {
                    Text("1. Chiếm 100% (.horizontal)")
                        .font(.headline).padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { index in
                                Rectangle()
                                    .fill(Color.blue.gradient)
                                    .overlay(Text("Page \(index)").font(.largeTitle).foregroundColor(.white))
                                    // Không truyền tham số gì thêm, tự động chiếm 100% chiều ngang của ScrollView
                                    .containerRelativeFrame(.horizontal)
                                    .frame(height: 200)
                            }
                        }
                    }
                    // Kết hợp scrollTargetBehavior để tạo hiệu ứng Paging hoàn hảo
                    .scrollTargetBehavior(.paging)
                }
                
                // MARK: - Cách 2: Count, Span, Spacing (Phân chia theo tỷ lệ)
                VStack(alignment: .leading) {
                    Text("2. Count & Span (Hiển thị mồi item kế tiếp)")
                        .font(.headline).padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { index in
                                Rectangle()
                                    .fill(Color.purple.gradient)
                                    .overlay(Text("Item \(index)").font(.title).foregroundColor(.white))
                                    // Chia ScrollView làm 4 phần, Item này chiếm 3 phần.
                                    // Apple tự động trừ hao khoảng trống (spacing) giúp bạn.
                                    .containerRelativeFrame(.horizontal, count: 4, span: 3, spacing: 16)
                                    .frame(height: 200)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    // Snap từng item một khi scroll
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                }
                
                // MARK: - Cách 3: Custom Logic bằng Closure
                VStack(alignment: .leading) {
                    Text("3. Custom Closure (Tự tính toán)")
                        .font(.headline).padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(1...10, id: \.self) { index in
                                Rectangle()
                                    .fill(Color.orange.gradient)
                                    .overlay(Text("\(index)").font(.title).foregroundColor(.white))
                                    // Custom: Chiều ngang item luôn bằng đúng 1/3 chiều ngang container
                                    .containerRelativeFrame(.horizontal) { length, axis in
                                        return length / 3.0
                                    }
                                    .frame(height: 150)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                }
                
            }
            .padding(.vertical)
        }
        .navigationTitle("Relative Frame")
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        NavigationStack {
            ContainerRelativeFrameDemo()
        }
    } else {
        Text("Tính năng này yêu cầu iOS 17 trở lên.")
    }
}
