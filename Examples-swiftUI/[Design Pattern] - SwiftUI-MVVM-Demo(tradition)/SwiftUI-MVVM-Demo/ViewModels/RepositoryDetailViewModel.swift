import Foundation
import Combine

@MainActor
final class RepositoryDetailViewModel: ObservableObject {
    @Published var repository: Repository
    
    init(repository: Repository) {
        self.repository = repository
    }
}
