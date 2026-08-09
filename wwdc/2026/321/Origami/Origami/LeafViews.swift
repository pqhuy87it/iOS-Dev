import SwiftUI

// A colored placeholder standing in for a real origami diagram image.
struct DiagramPlaceholder: View {
    let hue: Double
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(hue: hue, saturation: 0.35, brightness: 0.95))
            .overlay {
                Image(systemName: "square.on.square.dashed")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
            }
    }
}

struct StepTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StepSubtitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PhotoView: View {
    let photo: Photo
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hue: photo.hue, saturation: 0.5, brightness: 0.9))
            .frame(width: 140, height: 180)
            .overlay(alignment: .bottomLeading) {
                Text("#\(photo.id + 1)")
                    .font(.caption.bold())
                    .padding(6)
                    .foregroundStyle(.white)
            }
    }
}
