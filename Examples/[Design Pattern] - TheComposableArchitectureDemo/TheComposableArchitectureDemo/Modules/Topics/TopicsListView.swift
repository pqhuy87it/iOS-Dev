import SwiftUI
import ComposableArchitecture

struct TopicsListView: View {
    let store: StoreOf<TopicsFeature>
    
    var body: some View {
        NavigationStack {
            content
                .background(Color.black.ignoresSafeArea())
                .ignoresSafeArea(.container, edges: .top)
                .navigationDestination(for: Photo.self) { photo in
                    PhotoDetailView(photo: photo)
                }
                .onAppear {
                    store.send(.onAppear)
                }
        }
    }
    
    @ViewBuilder private var content: some View {
        if store.isLoading {
            ProgressView().tint(.white)
        } else if let error = store.errorMessage {
            ErrorView(error: NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: error])) {
                store.send(.onAppear)
            }
        } else if let heroTopic = store.heroTopic {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    HeroHeaderView(topic: heroTopic)
                    
                    VStack(spacing: 32) {
                        // KỲ DIỆU LÀ Ở ĐÂY: Vòng lặp ForEach kết hợp với hàm `scope`
                        // Hàm này tự động trích xuất Store con từ `rows` để truyền cho TopicHorizontalRow
                        ForEach(
                            store.scope(state: \.rows, action: \.row),
                            id: \.state.id
                        ) { rowStore in
                            TopicHorizontalRow(store: rowStore)
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 24)
                    .background(Color.black)
                }
            }
        }
    }
}
