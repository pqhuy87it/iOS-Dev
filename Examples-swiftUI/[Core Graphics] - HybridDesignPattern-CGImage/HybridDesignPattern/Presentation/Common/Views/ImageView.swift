import SwiftUI

struct ImageView: View {
    @StateObject private var viewModel: ImageViewModel

    init(viewModel: @autoclosure @escaping () -> ImageViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        content
            .onAppear {
                viewModel.send(.onAppear)
            }
    }
    
    @ViewBuilder private var content: some View {
        switch viewModel.state.image {
        case .notRequested:
            Color.clear
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
