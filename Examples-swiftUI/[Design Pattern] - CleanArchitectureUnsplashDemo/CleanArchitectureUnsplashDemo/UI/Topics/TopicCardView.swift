import SwiftUI

struct TopicCardView: View {
    let photo: ApiModel.Photo
    
    var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    ImageView(imageURL: photo.urls.small)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 260)
                        .cornerRadius(16)
                        .clipped()
                    
                    // Hiển thị số lượng Like hoặc thông tin khác thay cho "Activities"
                    Text("\(photo.user.name)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        .padding(10)
                }
            }
        }
}

#Preview {
    TopicCardView(photo: ApiModel.Photo.mock)
        .padding()
        .background(Color.black) // Thêm nền đen để dễ nhìn chữ màu trắng
}
