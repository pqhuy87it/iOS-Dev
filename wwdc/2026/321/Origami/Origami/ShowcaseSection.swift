import SwiftUI

// A horizontally scrolling showcase, composed *inside* the vertical LazyVStack.
// Demonstrates:
//  - nested LazyHStack inside a LazyVStack
//  - .scrollTransition effects
//  - pager state that lives in the parent so it survives scroll-off
//  - loading more content when a trailing spinner appears
struct ShowcaseSection: View {
    @State private var pager = ShowcasePager()

    var body: some View {
        Section {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(pager.photos) { photo in
                        PhotoView(photo: photo)
                            .scrollTransition { effect, phase in
                                effect
                                    .scaleEffect(1 - abs(phase.value) * 0.1)
                                    .opacity(1 - abs(phase.value) * 0.3)
                            }
                    }
                    if !pager.atEnd {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 80, height: 180)
                            .task { await pager.fetchNextPage() }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 200)
        } header: {
            Text("Showcase")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
                .id("showcase-header")   // programmatic scroll target
        }
    }
}
