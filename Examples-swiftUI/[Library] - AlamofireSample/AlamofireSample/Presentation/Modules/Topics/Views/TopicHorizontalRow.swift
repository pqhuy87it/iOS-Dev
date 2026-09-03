import SwiftUI

struct TopicHorizontalRow: View {
    @Environment(\.injected) private var injected: DIContainer
    @State private var photosState: Loadable<[Photo]> = .notRequested

    let topic: Topic
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(topic.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            switch photosState {
            case .notRequested:
                Color.clear.frame(height: 260).onAppear { loadPhotos() }
            case .isLoading:
                ProgressView().frame(maxWidth: .infinity).frame(height: 260)
            case let .loaded(photos):
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(photos) { photo in
                            NavigationLink(value: photo) {
                                TopicCardView(photo: photo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            case .failed:
                Text("Failed to load photos").foregroundColor(.gray).padding(.horizontal, 20)
            }
        }
    }

    private func loadPhotos() {
        $photosState.load {
            try await injected.interactors.topics.fetchTopicPhotos(slug: topic.slug, page: 1, perPage: 10)
        }
    }
}
