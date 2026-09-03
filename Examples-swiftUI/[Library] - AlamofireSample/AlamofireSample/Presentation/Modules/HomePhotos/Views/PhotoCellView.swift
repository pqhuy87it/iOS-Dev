import SwiftUI
import Combine

struct PhotoCell: View {
    let photo: Photo

    var body: some View {
        VStack(alignment: .leading) {
            Color(uiColor: .secondarySystemBackground)
                .aspectRatio(CGFloat(photo.width) / CGFloat(photo.height), contentMode: .fit)
                .overlay {
                    ImageView(url: photo.urls.small)
                }
                .clipped()
                .cornerRadius(12)

            Text(photo.user.name ?? photo.user.username)
                .font(.caption)
        }
    }
}
