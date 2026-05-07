import SwiftUI

struct TopicsListView: View {
    @Environment(\.injected) private var injected: DIContainer
    
    // Quản lý trạng thái tải danh sách Topics
    @State private var topicsState: Loadable<[ApiModel.Topic]> = .notRequested
    
    var body: some View {
        NavigationStack {
            content
                .background(Color.black.ignoresSafeArea())
                .ignoresSafeArea(.container, edges: .top)
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
                        // Hero Header lấy dữ liệu từ Topic đầu tiên
                        HeroHeaderView(topic: firstTopic)
                        
                        VStack(spacing: 32) {
                            // Duyệt qua các topic tiếp theo để tạo các dòng cuộn ngang
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
        .inject(.init(interactors: .stub)) // Ngăn việc gọi API thật trên Canvas
}
