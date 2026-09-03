import SwiftUI

struct ImageView: View {
    @Environment(\.injected) private var injected: DIContainer
    private let url: URL
    @State private var imageState: Loadable<UIImage> = .notRequested

    init(url: URL) {
        self.url = url
    }

    var body: some View {
        content
            .onChange(of: url) { _, _ in loadImage() }
    }

    @ViewBuilder private var content: some View {
        switch imageState {
        case .notRequested:
            Color.clear.onAppear { loadImage() }
        case .isLoading:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        case let .loaded(image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .failed:
            Text("Unable to load image")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
        }
    }

    private func loadImage() {
        $imageState.load {
            try await injected.interactors.images.loadImage(url: url)
        }
    }
}
