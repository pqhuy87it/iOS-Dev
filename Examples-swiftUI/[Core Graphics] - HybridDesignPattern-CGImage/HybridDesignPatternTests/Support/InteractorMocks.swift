import Foundation
import UIKit
import SwiftData
@testable import HybridDesignPattern

// MARK: - Test error

struct TestError: Error, Equatable {}

// MARK: - DTO fixtures

enum DTOFixtures {
    static func photos(ids: [String]) -> [PhotoDTO] {
        try! JSONDecoder().decode([PhotoDTO].self, from: JSONFixtures.photosArray(ids: ids))
    }

    static func topics(_ topics: [(id: String, slug: String)]) -> [TopicDTO] {
        try! JSONDecoder().decode([TopicDTO].self, from: JSONFixtures.topicsArray(topics))
    }

    static func searchResult(total: Int, totalPages: Int, photoIDs: [String]) -> SearchResultDTO {
        try! JSONDecoder().decode(
            SearchResultDTO.self,
            from: JSONFixtures.searchResult(total: total, totalPages: totalPages, photoIDs: photoIDs)
        )
    }
}

// MARK: - Mock repositories

final class MockPhotosRepository: PhotosRepositoryProtocol {
    var fetchPhotosResult: Result<[PhotoDTO], Error> = .success([])
    private(set) var fetchPhotosCallCount = 0
    private(set) var lastPage: Int?
    private(set) var lastPerPage: Int?

    func fetchPhotos(page: Int, perPage: Int) async throws -> [PhotoDTO] {
        fetchPhotosCallCount += 1
        lastPage = page
        lastPerPage = perPage
        return try fetchPhotosResult.get()
    }
}

final class MockTopicsRepository: TopicsRepositoryProtocol {
    var topicsResult: Result<[TopicDTO], Error> = .success([])
    var topicPhotosResult: Result<[PhotoDTO], Error> = .success([])
    private(set) var lastTopicsPage: Int?
    private(set) var lastTopicsPerPage: Int?
    private(set) var lastSlug: String?
    private(set) var lastPhotosPage: Int?
    private(set) var lastPhotosPerPage: Int?

    func fetchTopics(page: Int, perPage: Int) async throws -> [TopicDTO] {
        lastTopicsPage = page
        lastTopicsPerPage = perPage
        return try topicsResult.get()
    }

    func fetchTopicPhotos(slug: String, page: Int, perPage: Int) async throws -> [PhotoDTO] {
        lastSlug = slug
        lastPhotosPage = page
        lastPhotosPerPage = perPage
        return try topicPhotosResult.get()
    }
}

final class MockSearchRepository: SearchRepositoryProtocol {
    var searchResult: Result<SearchResultDTO, Error> = .success(
        DTOFixtures.searchResult(total: 0, totalPages: 0, photoIDs: [])
    )
    var historyResult: Result<[DBModel.SearchHistory], Error> = .success([])
    var saveError: Error?
    private(set) var lastQuery: String?
    private(set) var savedKeywords: [String] = []

    func searchPhotos(query: String, page: Int, perPage: Int) async throws -> SearchResultDTO {
        lastQuery = query
        return try searchResult.get()
    }

    @MainActor
    func fetchSearchHistory() async throws -> [DBModel.SearchHistory] {
        try historyResult.get()
    }

    func saveSearchKeyword(_ keyword: String) async throws {
        if let saveError { throw saveError }
        savedKeywords.append(keyword)
    }
}

final class MockImagesRepository: ImagesRepositoryProtocol {
    var result: Result<UIImage, Error>
    private(set) var lastURL: URL?

    init(result: Result<UIImage, Error> = .success(UIImage())) {
        self.result = result
    }

    func loadImage(url: URL) async throws -> UIImage {
        lastURL = url
        return try result.get()
    }
}
