import SwiftUI
import Foundation
import Combine

// MARK: - PhotoCell (Component displaying 1 photo in Grid)
struct PhotoCell: View {
    let photo: Photo
    
    var body: some View {
        VStack(alignment: .leading) {
            // Use small image (small or thumb) for list to increase performance
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
    PhotoCell(photo: Photo.mock)
        .frame(width: 180) // Limit width for preview
        .padding()
}