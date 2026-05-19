import SwiftUI

struct HeroHeaderView: View {
    let topic: ApiModel.Topic
    
    var body: some View {
            ZStack(alignment: .bottomLeading) {
                // Lấy cover_photo từ API Topics
                if let coverURL = topic.coverPhoto?.urls.regular {
                    ImageView(imageURL: coverURL)
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, minHeight: 500, maxHeight: 500)
                        .clipped()
                }
                
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.9), .clear, .black.opacity(0.3)]),
                    startPoint: .bottom,
                    endPoint: .top
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("FEATURED TOPIC")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    Text(topic.title)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let desc = topic.description {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
}

#Preview {
    HeroHeaderView(topic: ApiModel.Topic.mock)
        .background(Color.black)
        .ignoresSafeArea()
}
