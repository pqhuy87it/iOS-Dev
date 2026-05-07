import SwiftUI
import ComposableArchitecture

struct TopicCardView: View {
    let photo: Photo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                ImageView(
                    store: Store(initialState: ImageFeature.State(url: photo.urls.small)) {
                        ImageFeature()
                    }
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 180, height: 260)
                .cornerRadius(16)
                .clipped()
                
                // Display number of Likes or other information instead of "Activities"
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
    TopicCardView(photo: Photo.mock)
        .padding()
        .background(Color.black) // Add black background to easily see white text
}
