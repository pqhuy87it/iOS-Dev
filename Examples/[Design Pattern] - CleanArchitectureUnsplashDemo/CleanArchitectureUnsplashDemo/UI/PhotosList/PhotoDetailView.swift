import SwiftUI

struct PhotoDetailView: View {
    
    let photo: ApiModel.Photo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tải ảnh kích thước lớn (regular) cho detail
                ImageView(imageURL: photo.urls.regular)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Hiển thị tác giả
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                        Text(photo.user.name)
                            .font(.headline)
                    }
                    
                    // Hiển thị mô tả ảnh (nếu có)
                    if let description = photo.description ?? photo.altDescription {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Kích thước ảnh gốc
                    Text("Kích thước gốc: \(photo.width) x \(photo.height)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Chi tiết ảnh")
        .navigationBarTitleDisplayMode(.inline)
    }
}
