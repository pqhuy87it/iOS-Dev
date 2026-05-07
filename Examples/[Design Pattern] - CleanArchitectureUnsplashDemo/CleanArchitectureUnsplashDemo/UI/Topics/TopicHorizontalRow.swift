import SwiftUI

struct TopicHorizontalRow: View {
    @Environment(\.injected) private var injected: DIContainer
    let topic: ApiModel.Topic
    // Mỗi dòng tự quản lý trạng thái tải ảnh của topic đó
    @State private var photosState: Loadable<[ApiModel.Photo]> = .notRequested
    
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
                        }
                    }
                    .padding(.horizontal, 20)
                }
            case .failed:
                Text("Không thể tải ảnh").foregroundColor(.gray).padding(.horizontal, 20)
            }
        }
    }
    
    private func loadPhotos() {
        $photosState.load {
            // Gọi API lấy ảnh theo slug của topic
            try await injected.interactors.photos.fetchTopicPhotos(slug: topic.slug, page: 1, perPage: 10)
        }
    }
}

#Preview {
    TopicHorizontalRow(topic: ApiModel.Topic.mock)
        .inject(.init(interactors: .stub)) // Bắt buộc phải có dòng này
        .background(Color.black)
}
