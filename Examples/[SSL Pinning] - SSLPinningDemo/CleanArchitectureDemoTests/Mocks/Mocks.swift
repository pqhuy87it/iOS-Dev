import Foundation
@testable import CleanArchitectureDemo

class MockUnsplashWebRepository: UnsplashWebRepositoryProtocol {
    var session: URLSession = .shared
    var baseURL: String = ""
    
    var photosToReturn: [ApiModel.Photo] = []
    var searchResultToReturn: ApiModel.SearchResult = ApiModel.SearchResult(total: 0, totalPages: 0, results: [])
    var topicsToReturn: [ApiModel.Topic] = []
    var topicPhotosToReturn: [ApiModel.Photo] = []
    
    var errorToThrow: Error?
    
    func fetchLatestPhotos(page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        if let error = errorToThrow { throw error }
        return photosToReturn
    }
    
    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> ApiModel.SearchResult {
        if let error = errorToThrow { throw error }
        return searchResultToReturn
    }
    
    func fetchTopics(page: Int, perPage: Int) async throws -> [ApiModel.Topic] {
        if let error = errorToThrow { throw error }
        return topicsToReturn
    }
    
    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [ApiModel.Photo] {
        if let error = errorToThrow { throw error }
        return topicPhotosToReturn
    }
}

class MockSearchDBRepository: SearchDBRepositoryProtocol {
    var historyToReturn: [DBModel.SearchHistory] = []
    var errorToThrow: Error?
    var savedKeyword: String?
    
    func fetchSearchHistory() async throws -> [DBModel.SearchHistory] {
        if let error = errorToThrow { throw error }
        return historyToReturn
    }
    
    func saveSearchKeyword(_ keyword: String) async throws {
        if let error = errorToThrow { throw error }
        savedKeyword = keyword
    }
}
