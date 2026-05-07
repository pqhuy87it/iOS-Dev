import SwiftUI
import Foundation
import Combine

// MARK: - PhotoCell (Component hiển thị 1 ảnh trong Grid)
struct PhotoCell: View {
    let photo: ApiModel.Photo
    
    var body: some View {
        VStack(alignment: .leading) {
            // Dùng ảnh nhỏ (small hoặc thumb) cho list để tăng hiệu năng
            ImageView(imageURL: photo.urls.small)
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                .clipped()
                .cornerRadius(12)
                .shadow(radius: 3)
            
            Text(photo.user.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }
}

#Preview {
    PhotoCell(photo: ApiModel.Photo.mock)
        .frame(width: 180) // Giới hạn chiều rộng để xem thử
        .padding()
}
