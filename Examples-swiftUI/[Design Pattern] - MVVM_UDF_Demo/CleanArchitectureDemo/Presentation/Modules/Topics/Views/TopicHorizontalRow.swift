import SwiftUI

struct TopicHorizontalRow: View {
    let topic: Topic
    @StateObject private var viewModel: TopicRowViewModel
    
    init(topic: Topic, viewModel: @autoclosure @escaping () -> TopicRowViewModel) {
        self.topic = topic
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(topic.title) //
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            switch viewModel.state.photos {
            case .notRequested:
                Color.clear.frame(height: 260).onAppear { viewModel.send(.loadPhotos) }
            case .isLoading:
                ProgressView().frame(maxWidth: .infinity).frame(height: 260) //
            case let .loaded(photos):
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(photos) { photo in
                            NavigationLink(value: photo) {
                                TopicCardView(photo: photo) //
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            case .failed:
                Text("Failed to load photos").foregroundColor(.gray).padding(.horizontal, 20) //
            }
        }
    }
}
