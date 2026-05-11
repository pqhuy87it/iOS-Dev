import SwiftUI
import Foundation

// 4. View con (Cell) hiển thị từng bức ảnh
struct PhotoCell: View {
    let photo: PhotoItem
    
    var body: some View {
        ZStack {
            // Khung nền màu xám
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit) // Hình vuông
            
            // Xử lý các trạng thái hiển thị
            if let image = photo.image {
                // Đã tải xong -> Hiện ảnh
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if photo.isWaitingOrLoading {
                // Đang chờ trong hàng đợi hoặc đang tải -> Hiện Loading ở giữa
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                // Tải lỗi -> Hiện icon cảnh báo
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundColor(.gray)
            }
        }
        .clipped()
        .cornerRadius(10)
    }
}
