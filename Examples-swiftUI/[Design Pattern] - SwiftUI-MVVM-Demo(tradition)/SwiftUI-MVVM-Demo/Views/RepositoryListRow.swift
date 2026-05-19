import SwiftUI

struct RepositoryListRow: View {
    // Xóa @State vì row này chỉ nhận data từ List truyền vào, không tự thay đổi data
    let repository: Repository

    var body: some View {
        NavigationLink(
            destination: RepositoryDetailView(
                viewModel: RepositoryDetailViewModel(repository: repository)
            )
        ) {
            Text(repository.fullName)
        }
    }
}
