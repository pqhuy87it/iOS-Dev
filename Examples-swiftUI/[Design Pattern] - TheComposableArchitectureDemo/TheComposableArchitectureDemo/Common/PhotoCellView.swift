import SwiftUI
import Foundation
import ComposableArchitecture

// MARK: - PhotoCell (Component displaying 1 photo in Grid)
struct PhotoCell: View {
    let photo: Photo
    
    var body: some View {
        VStack(alignment: .leading) {
            
            // Khởi tạo ImageView với Store độc lập cho từng bức ảnh
            ImageView(
                store: Store(initialState: ImageFeature.State(url: photo.urls.small)) {
                    ImageFeature()
                }
            )
            // Lưu ý: Đảm bảo bên trong code của ImageView bạn đã cấu hình .resizable() và .aspectRatio(contentMode: .fill)
            // cho Image(uiImage:) nhé.
            .frame(maxWidth: .infinity)
            .aspectRatio(CGFloat(photo.width) / CGFloat(photo.height), contentMode: .fit)
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
    PhotoCell(photo: Photo.mock)
        .frame(width: 180) // Limit width for preview
        .padding()
}
