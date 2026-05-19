import SwiftUI
import ComposableArchitecture

struct PhotoDetailView: View {
    
    let photo: Photo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Load large size image (regular) for detail
                // Khởi tạo ImageView với Store độc lập cho từng bức ảnh
                ImageView(
                    store: Store(initialState: ImageFeature.State(url: photo.urls.small)) {
                        ImageFeature()
                    }
                )
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .cornerRadius(16)
                .shadow(radius: 5)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Display author
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                        Text(photo.user.name)
                            .font(.headline)
                    }
                    
                    // Display photo description (if any)
                    if let description = photo.description ?? photo.altDescription {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Original photo size
                    Text("Original size: \(photo.width) x \(photo.height)")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
