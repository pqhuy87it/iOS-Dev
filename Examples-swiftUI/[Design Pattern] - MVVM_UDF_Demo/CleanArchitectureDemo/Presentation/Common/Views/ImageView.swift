import SwiftUI

struct ImageView: View {
    let imageURL: URL
    
    // Lắng nghe ViewModel
    @StateObject private var viewModel: ImageViewModel
    
    // Inject ViewModel qua init thay vì DIContainer environment
    init(imageURL: URL, viewModel: @autoclosure @escaping () -> ImageViewModel) {
        self.imageURL = imageURL
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        content
            .onAppear {
                viewModel.send(.loadImage(imageURL))
            }
    }
    
    @ViewBuilder private var content: some View {
        switch viewModel.state.image {
        case .notRequested:
            Color.clear // Sẽ load khi onAppear
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
}
