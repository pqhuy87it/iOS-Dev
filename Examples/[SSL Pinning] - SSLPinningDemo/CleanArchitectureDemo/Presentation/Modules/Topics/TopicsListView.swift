import SwiftUI

struct TopicsListView: View {
    @Environment(\.injected) private var injected: DIContainer
    
    // Manage load state of Topics list
    @State private var topicsState: Loadable<[Topic]> = .notRequested
    
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
        switch topicsState {
        case .notRequested:
            Color.clear.onAppear { loadTopics() }
        case .isLoading:
            ProgressView().tint(.white)
        case let .loaded(topics):
            if let firstTopic = topics.first {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Header gets data from the first Topic
                        HeroHeaderView(topic: firstTopic)
                        
                        VStack(spacing: 32) {
                            // Iterate through next topics to create horizontal scroll rows
                            ForEach(topics.dropFirst()) { topic in
                                TopicHorizontalRow(topic: topic)
                            }
                            Spacer().frame(height: 100)
                        }
                        .padding(.top, 24)
                        .background(Color.black)
                    }
                }
            }
        case let .failed(error):
            ErrorView(error: error) { loadTopics() }
        }
    }
    
    private func loadTopics() {
        $topicsState.load {
            try await injected.interactors.photos.fetchTopics(page: 1, perPage: 10)
        }
    }
}

#Preview {
    TopicsListView()
        .inject(.init(interactors: .stub)) // Prevent calling real API on Canvas
}