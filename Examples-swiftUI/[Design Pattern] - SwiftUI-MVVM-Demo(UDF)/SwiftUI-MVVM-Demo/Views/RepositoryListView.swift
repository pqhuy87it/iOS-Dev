import SwiftUI

struct RepositoryListView : View {
    // Sử dụng @StateObject để View này nắm quyền sở hữu (owner) ViewModel
    @StateObject var viewModel: RepositoryListViewModel = RepositoryListViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.repositories) { repository in
                RepositoryListRow(repository: repository)
            }
            .navigationTitle("Repositories") // API mới thay cho navigationBarTitle
            // Sử dụng Alert API mới
            .alert("Error", isPresented: $viewModel.isErrorShown) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .onAppear {
            viewModel.apply(.onAppear)
        }
    }
}
