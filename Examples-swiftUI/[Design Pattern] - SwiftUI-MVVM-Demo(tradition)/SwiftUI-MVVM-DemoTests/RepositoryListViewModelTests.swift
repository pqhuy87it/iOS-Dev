import Foundation
import Combine
import XCTest
@testable import SwiftUI_MVVM_Demo

@MainActor
final class RepositoryListViewModelTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    func test_updateRepositoriesWhenOnAppear() async {
        let apiService = MockAPIService()
        let expectedResponse = SearchRepositoryResponse(
            items: [
                Repository(
                    id: 1,
                    fullName: "foo",
                    description: nil,
                    stargazersCount: 0,
                    language: nil,
                    owner: User(id: 1, login: "bar", avatarUrl: URL(string: "http://baz.com")!)
                )
            ]
        )
        
        // Setup stub bằng Result.success
        apiService.stub(for: SearchRepositoryRequest.self, response: .success(expectedResponse))
        
        let viewModel = makeViewModel(apiService: apiService)
        let expectation = XCTestExpectation(description: "Fetch repositories thành công")
        
        viewModel.$repositories
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.apply(.onAppear)
        
        // Đợi Task hoàn thành
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertFalse(viewModel.repositories.isEmpty)
        XCTAssertEqual(viewModel.repositories.first?.fullName, "foo")
    }
    
    func test_serviceErrorWhenOnAppear() async {
        let apiService = MockAPIService()
        
        // Setup stub bằng Result.failure
        apiService.stub(for: SearchRepositoryRequest.self, response: .failure(APIServiceError.responseError))
        
        let viewModel = makeViewModel(apiService: apiService)
        let expectation = XCTestExpectation(description: "Bắt được lỗi API")
        
        viewModel.$isErrorShown
            .dropFirst()
            .filter { $0 == true }
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.apply(.onAppear)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertTrue(viewModel.isErrorShown)
    }
    
    // Các test dưới đây giữ nguyên, không cần setup stub vì MockAPIService đã có Fallback an toàn
    func test_logListViewWhenOnAppear() {
        let trackerService = MockTrackerService()
        let viewModel = makeViewModel(trackerService: trackerService)
        
        viewModel.apply(.onAppear)
        XCTAssertTrue(trackerService.loggedTypes.contains(.listView))
    }
    
    func test_showIconEnabledWhenOnAppear() {
        let experimentService = MockExperimentService()
        experimentService.stubs[.showIcon] = true
        let viewModel = makeViewModel(experimentService: experimentService)

        viewModel.apply(.onAppear)
        XCTAssertTrue(viewModel.shouldShowIcon)
    }
    
    func test_showIconDisabledWhenOnAppear() {
        let experimentService = MockExperimentService()
        experimentService.stubs[.showIcon] = false
        let viewModel = makeViewModel(experimentService: experimentService)
        
        viewModel.apply(.onAppear)
        XCTAssertFalse(viewModel.shouldShowIcon)
    }
    
    private func makeViewModel(
        apiService: APIServiceType = MockAPIService(),
        trackerService: TrackerType = MockTrackerService(),
        experimentService: ExperimentServiceType = MockExperimentService()
    ) -> RepositoryListViewModel {
        // Code khởi tạo gọn gàng như cũ, không cần check rỗng
        return RepositoryListViewModel(
            apiService: apiService,
            trackerService: trackerService,
            experimentService: experimentService
        )
    }
}
