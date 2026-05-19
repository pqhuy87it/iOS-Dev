import SwiftUI

struct RepositoryDetailView: View {
    // Dùng @ObservedObject vì ViewModel được khởi tạo và truyền từ RepositoryListRow
    @ObservedObject var viewModel: RepositoryDetailViewModel
    
    var body: some View {
        Text(viewModel.repository.fullName)
            .navigationTitle(viewModel.repository.fullName)
            .navigationBarTitleDisplayMode(.inline)
    }
}
