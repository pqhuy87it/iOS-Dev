import Foundation
import SwiftUI
import Combine

@MainActor // Đảm bảo mọi thay đổi @Published đều diễn ra trên Main Thread
final class RepositoryListViewModel: ObservableObject {
    
    // MARK: Output
    @Published private(set) var repositories: [Repository] = []
    @Published var isErrorShown = false
    @Published var errorMessage = ""
    @Published private(set) var shouldShowIcon = false
    
    private let apiService: APIServiceType
    private let trackerService: TrackerType
    private let experimentService: ExperimentServiceType
    
    init(apiService: APIServiceType? = nil,
         trackerService: TrackerType? = nil,
         experimentService: ExperimentServiceType? = nil) {
        self.apiService = apiService ?? APIService()
        self.trackerService = trackerService ?? TrackerService()
        self.experimentService = experimentService ?? ExperimentService()
    }
    
    // MARK: - Actions (MVVM Truyền thống)
    // Thay vì gửi event qua hàm apply(), ta định nghĩa trực tiếp hàm xử lý
    func fetchRepositories() {
        trackerService.log(type: .listView)
        shouldShowIcon = experimentService.experiment(for: .showIcon)
        
        // Gọi API bằng Task (Async/Await)
        Task {
            do {
                let request = SearchRepositoryRequest()
                let response = try await apiService.response(from: request)
                self.repositories = response.items
            } catch let error as APIServiceError {
                self.errorMessage = error.localizedDescription
                self.isErrorShown = true
            } catch {
                self.errorMessage = "Unknown error occurred"
                self.isErrorShown = true
            }
        }
    }
}
