import SwiftUI
import Combine

// Tại nơi sử dụng (Ví dụ: PhotoCell)
struct PhotoCell: View {
    let photo: Photo
    // Giả sử ta có AppEnvironment truyền xuống hoặc tạo factory
    @Environment(\.viewModelFactory) var factory
    
    var body: some View {
        VStack(alignment: .leading) {
            // Truyền ViewModel từ Factory vào ImageView
            ImageView(
                imageURL: photo.urls.small,
                viewModel: factory.makeImageViewModel()
            )
            .aspectRatio(contentMode: .fill)
            .frame(height: 150)
            .clipped()
            .cornerRadius(12)
            
            Text(photo.user.name)
                .font(.caption)
        }
    }
}
