import SwiftUI
import Foundation

struct PhotoGridView: View {
    @StateObject private var viewModel = PhotoGridViewModel()
    
    // Cấu hình hiển thị 3 cột cạnh nhau
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                // LazyVGrid giúp render dạng lưới
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.photos) { photo in
                        PhotoCell(photo: photo)
                    }
                }
                .padding()
            }
            .navigationTitle("Operation Queue (Max 3)")
            .onAppear {
                // Ngay khi mở màn hình lên, nhét cả 20 task vào Queue
                viewModel.startLoadingAllImages()
            }
        }
    }
}
