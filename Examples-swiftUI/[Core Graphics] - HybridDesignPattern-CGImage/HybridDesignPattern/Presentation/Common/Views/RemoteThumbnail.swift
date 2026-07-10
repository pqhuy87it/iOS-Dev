import Foundation
import SwiftUI

struct RemoteThumbnail: View {
    let url: URL
    var maxPixelSize: CGFloat = 300

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.15))
            }
        }
        .task(id: url) {
            image = try? await RemoteThumbnailLoader.shared.thumbnail(
                from: url, maxPixelSize: maxPixelSize)
        }
    }
}
