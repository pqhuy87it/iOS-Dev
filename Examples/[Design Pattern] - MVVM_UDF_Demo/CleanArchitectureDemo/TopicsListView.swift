import SwiftUI

struct TopicsListView: View {
    @Environment(\.viewModelFactory) private var factory
    @StateObject private var viewModel: TopicsViewModel

    init(viewModel: @autoclosure @escaping () -> TopicsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.black.ignoresSafeArea())
                .ignoresSafeArea(.container, edges: .top)
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state.topics {
        case .notRequested:
            Color.clear.onAppear { viewModel.send(.loadTopics) }
        case .isLoading:
            ProgressView().tint(.white) //
        case let .loaded(topics):
            if let firstTopic = topics.first {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HeroHeaderView(topic: firstTopic) //

                        VStack(spacing: 32) {
                            ForEach(topics.dropFirst()) { topic in
                                // Khởi tạo Row kèm ViewModel từ Factory
                                TopicHorizontalRow(topic: topic,
                                                   viewModel: factory.makeTopicRowViewModel(topic: topic))
                            }
                            Spacer().frame(height: 100) //
                        }
                        .padding(.top, 24)
                        .background(Color.black)
                    }
                }
            }
        case let .failed(error):
            ErrorView(error: error) { viewModel.send(.refreshTopics) } //
        }
    }
}
